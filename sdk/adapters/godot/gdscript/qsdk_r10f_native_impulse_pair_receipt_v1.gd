class_name SporeQsdkR10fNativeImpulsePairReceiptV1
extends RefCounted
# gdlint: disable=max-line-length

## Variable-step, paired-arm successor to the qualified R10E scalar receipt.
##
## R10E fixed its kick at semantic step 900. R10F reaches the same kick only
## after a variable-length, same-body prone-to-stand precondition, so copying
## that timestamp would be false. This module reuses R10E's exact scalar-space
## tolerances and host-real magnitude replay while binding the actual R10F
## global step and subtracting the matched no-kick arm's one-step velocity
## change. It is pure: all native values are supplied by the worker after the
## completed effect step, and this module performs no world or body operation.

const R10eScalarValidator := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10e_native_impulse_scalar_receipt_validation_v2.gd"
)
const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")

const GATE_ID := "QSDK-R10F"
const VALIDATOR_ID := "sporespore_qsdk_r10f_variable_step_native_impulse_pair_validator_v1"
const RECEIPT_SCHEMA := "sporespore_qsdk_r10f_native_impulse_pair_receipt_v1"
const BUILD_SCHEMA := "sporespore_qsdk_r10f_native_impulse_pair_receipt_build_v1"
const FAILURE_SCHEMA := "sporespore_qsdk_r10f_native_impulse_pair_failure_v1"
const ACTIVE_ARM_ID := "kick_passive_recovery_resume"
const BASELINE_ARM_ID := "matched_no_kick_continuation"
const HISTORICAL_VALIDATOR_PATH := "sdk/adapters/godot/gdscript/qsdk_r10e_native_impulse_scalar_receipt_validation_v2.gd"
const HISTORICAL_VALIDATOR_BYTE_LENGTH := 13931
const HISTORICAL_VALIDATOR_RAW_SHA256 := "sha256:6552965575549399ea189efde20bef639007c11467c24cb9bd5dca36e24d022c"
const NATIVE_EFFECT_FLOOR_M_S := 0.0001
const SOURCE_KEYS := [
	"attempt_id",
	"completed_effect_global_step",
	"active_model_instance_id",
	"baseline_model_instance_id",
	"active_prefix_session_id",
	"baseline_prefix_session_id",
	"active_prefix_session_receipt_sha256",
	"baseline_prefix_session_receipt_sha256",
	"active_task_frame_forward_axis_world_host_real",
	"active_task_frame_lateral_axis_world_host_real",
	"baseline_task_frame_forward_axis_world_host_real",
	"baseline_task_frame_lateral_axis_world_host_real",
	"active_impulse_world_n_s",
	"active_pre_application_velocity_world_m_s",
	"active_completed_effect_velocity_world_m_s",
	"baseline_pre_event_velocity_world_m_s",
	"baseline_completed_effect_velocity_world_m_s",
	"active_application_count",
	"baseline_application_count",
]
const RECEIPT_KEYS := [
	"schema_version",
	"gate_id",
	"validator_id",
	"attempt_id",
	"completed_effect_global_step",
	"ordered_arm_ids",
	"source",
	"computed_measurements",
	"predicates",
	"predicate_count",
	"all_predicates_passed",
	"historical_scalar_validator_path",
	"historical_scalar_validator_byte_length",
	"historical_scalar_validator_raw_sha256",
	"r10e_scalar_tolerance_math_reused",
	"r10e_fixed_step_900_copied_into_r10f",
	"matched_no_kick_delta_subtracted",
	"source_measurement",
	"interaction_retained_separately",
	"kick_work_included_in_recovery_epoch_ledger",
	"mechanical_energy_residual_used_as_effect_source",
	"force_aware_recovery_used",
	"physical_acceptance_authority",
	"release_authority",
	"payload_sha256",
]


static func build_pair_receipt_v1(sdk: Object, source: Dictionary) -> Dictionary:
	if sdk == null:
		return _failure("QSDK_R10F_IMPULSE_PAIR_SDK_MISSING")
	var evaluation := _evaluate_source_v1(source)
	if not bool(evaluation.get("ok", false)):
		return evaluation
	var receipt := {
		"schema_version": RECEIPT_SCHEMA,
		"gate_id": GATE_ID,
		"validator_id": VALIDATOR_ID,
		"attempt_id": String(source["attempt_id"]),
		"completed_effect_global_step": int(source["completed_effect_global_step"]),
		"ordered_arm_ids": [BASELINE_ARM_ID, ACTIVE_ARM_ID],
		"source": source.duplicate(true),
		"computed_measurements":
		(evaluation["computed_measurements"] as Dictionary).duplicate(true),
		"predicates": (evaluation["predicates"] as Dictionary).duplicate(true),
		"predicate_count": int(evaluation["predicate_count"]),
		"all_predicates_passed": true,
		"historical_scalar_validator_path": HISTORICAL_VALIDATOR_PATH,
		"historical_scalar_validator_byte_length": HISTORICAL_VALIDATOR_BYTE_LENGTH,
		"historical_scalar_validator_raw_sha256": HISTORICAL_VALIDATOR_RAW_SHA256,
		"r10e_scalar_tolerance_math_reused": true,
		"r10e_fixed_step_900_copied_into_r10f": false,
		"matched_no_kick_delta_subtracted": true,
		"source_measurement": true,
		"interaction_retained_separately": true,
		"kick_work_included_in_recovery_epoch_ledger": false,
		"mechanical_energy_residual_used_as_effect_source": false,
		"force_aware_recovery_used": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"payload_sha256": "",
	}
	receipt["payload_sha256"] = _payload_sha256_v1(sdk, receipt)
	if not pair_receipt_valid_v1(sdk, receipt):
		return _failure("QSDK_R10F_IMPULSE_PAIR_RECEIPT_INVALID")
	return {
		"schema_version": BUILD_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"pair_receipt": receipt,
		"pair_receipt_sha256": String(receipt["payload_sha256"]),
		"active_native_effect_velocity_delta_m_s":
		float((receipt["computed_measurements"] as Dictionary)["paired_kick_effect_magnitude_m_s"]),
		"baseline_natural_velocity_delta_m_s":
		float(
			(receipt["computed_measurements"] as Dictionary)["baseline_velocity_delta_magnitude_m_s"]
		),
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func pair_receipt_valid_v1(sdk: Object, receipt: Dictionary) -> bool:
	if (
		sdk == null
		or not _keys_exact_v1(receipt, RECEIPT_KEYS)
		or String(receipt.get("schema_version", "")) != RECEIPT_SCHEMA
		or String(receipt.get("gate_id", "")) != GATE_ID
		or String(receipt.get("validator_id", "")) != VALIDATOR_ID
		or receipt.get("ordered_arm_ids") != [BASELINE_ARM_ID, ACTIVE_ARM_ID]
		or not (receipt.get("source") is Dictionary)
		or not (receipt.get("computed_measurements") is Dictionary)
		or not (receipt.get("predicates") is Dictionary)
		or String(receipt.get("historical_scalar_validator_path", "")) != HISTORICAL_VALIDATOR_PATH
		or (
			int(receipt.get("historical_scalar_validator_byte_length", -1))
			!= HISTORICAL_VALIDATOR_BYTE_LENGTH
		)
		or (
			String(receipt.get("historical_scalar_validator_raw_sha256", ""))
			!= HISTORICAL_VALIDATOR_RAW_SHA256
		)
		or not bool(receipt.get("r10e_scalar_tolerance_math_reused", false))
		or bool(receipt.get("r10e_fixed_step_900_copied_into_r10f", true))
		or not bool(receipt.get("matched_no_kick_delta_subtracted", false))
		or not bool(receipt.get("source_measurement", false))
		or not bool(receipt.get("interaction_retained_separately", false))
		or bool(receipt.get("kick_work_included_in_recovery_epoch_ledger", true))
		or bool(receipt.get("mechanical_energy_residual_used_as_effect_source", true))
		or bool(receipt.get("force_aware_recovery_used", true))
		or bool(receipt.get("physical_acceptance_authority", true))
		or bool(receipt.get("release_authority", true))
	):
		return false
	var source: Dictionary = receipt["source"]
	var evaluation := _evaluate_source_v1(source)
	if not bool(evaluation.get("ok", false)):
		return false
	if (
		String(receipt.get("attempt_id", "")) != String(source.get("attempt_id", ""))
		or (
			int(receipt.get("completed_effect_global_step", -1))
			!= int(source.get("completed_effect_global_step", -2))
		)
		or int(receipt.get("predicate_count", -1)) != int(evaluation["predicate_count"])
		or not bool(receipt.get("all_predicates_passed", false))
		or receipt.get("computed_measurements") != evaluation.get("computed_measurements")
		or receipt.get("predicates") != evaluation.get("predicates")
	):
		return false
	return String(receipt.get("payload_sha256", "")) == _payload_sha256_v1(sdk, receipt)


static func _evaluate_source_v1(source: Dictionary) -> Dictionary:
	if not _keys_exact_v1(source, SOURCE_KEYS):
		return _failure("QSDK_R10F_IMPULSE_PAIR_SOURCE_KEY_SET_MISMATCH")
	for string_key in [
		"attempt_id",
		"active_model_instance_id",
		"baseline_model_instance_id",
		"active_prefix_session_id",
		"baseline_prefix_session_id",
		"active_prefix_session_receipt_sha256",
		"baseline_prefix_session_receipt_sha256",
	]:
		if typeof(source[string_key]) != TYPE_STRING or String(source[string_key]).is_empty():
			return _failure("QSDK_R10F_IMPULSE_PAIR_SOURCE_STRING_INVALID:%s" % string_key)
	if (
		typeof(source["completed_effect_global_step"]) != TYPE_INT
		or typeof(source["active_application_count"]) != TYPE_INT
		or typeof(source["baseline_application_count"]) != TYPE_INT
	):
		return _failure("QSDK_R10F_IMPULSE_PAIR_SOURCE_INTEGER_INVALID")
	var vector_keys := [
		"active_task_frame_forward_axis_world_host_real",
		"active_task_frame_lateral_axis_world_host_real",
		"baseline_task_frame_forward_axis_world_host_real",
		"baseline_task_frame_lateral_axis_world_host_real",
		"active_impulse_world_n_s",
		"active_pre_application_velocity_world_m_s",
		"active_completed_effect_velocity_world_m_s",
		"baseline_pre_event_velocity_world_m_s",
		"baseline_completed_effect_velocity_world_m_s",
	]
	var vectors := {}
	for vector_key_value in vector_keys:
		var vector_key := String(vector_key_value)
		var components := _finite_components_v1(source[vector_key])
		if components.is_empty():
			return _failure("QSDK_R10F_IMPULSE_PAIR_VECTOR_INVALID:%s" % vector_key)
		vectors[vector_key] = components
	var active_forward: Array = vectors["active_task_frame_forward_axis_world_host_real"]
	var active_lateral: Array = vectors["active_task_frame_lateral_axis_world_host_real"]
	var baseline_forward: Array = vectors["baseline_task_frame_forward_axis_world_host_real"]
	var baseline_lateral: Array = vectors["baseline_task_frame_lateral_axis_world_host_real"]
	var active_impulse: Array = vectors["active_impulse_world_n_s"]
	var active_delta := _subtract_v1(
		vectors["active_completed_effect_velocity_world_m_s"],
		vectors["active_pre_application_velocity_world_m_s"],
	)
	var baseline_delta := _subtract_v1(
		vectors["baseline_completed_effect_velocity_world_m_s"],
		vectors["baseline_pre_event_velocity_world_m_s"],
	)
	var paired_delta := _subtract_v1(active_delta, baseline_delta)
	var recomputed_world_impulse := [
		float(active_lateral[0]) * R10eScalarValidator.EXPECTED_IMPULSE_MAGNITUDE_N_S,
		float(active_lateral[1]) * R10eScalarValidator.EXPECTED_IMPULSE_MAGNITUDE_N_S,
		float(active_lateral[2]) * R10eScalarValidator.EXPECTED_IMPULSE_MAGNITUDE_N_S,
	]
	var active_delta_magnitude := _host_real_length_v1(active_delta)
	var baseline_delta_magnitude := _host_real_length_v1(baseline_delta)
	var paired_delta_magnitude := _host_real_length_v1(paired_delta)
	var predicates := {
		"actual_global_step_positive": int(source["completed_effect_global_step"]) > 0,
		"distinct_model_instances":
		String(source["active_model_instance_id"]) != String(source["baseline_model_instance_id"]),
		"distinct_prefix_sessions":
		String(source["active_prefix_session_id"]) != String(source["baseline_prefix_session_id"]),
		"active_prefix_session_receipt_digest_valid":
		_digest_valid_v1(String(source["active_prefix_session_receipt_sha256"])),
		"baseline_prefix_session_receipt_digest_valid":
		_digest_valid_v1(String(source["baseline_prefix_session_receipt_sha256"])),
		"active_application_count_exact": int(source["active_application_count"]) == 1,
		"baseline_application_count_exact": int(source["baseline_application_count"]) == 0,
		"active_forward_axis_unit_within_r10e_allowance":
		absf(_norm_v1(active_forward) - 1.0) <= R10eScalarValidator.HOST_REAL_UNIT_NORM_ALLOWANCE,
		"active_lateral_axis_unit_within_r10e_allowance":
		absf(_norm_v1(active_lateral) - 1.0) <= R10eScalarValidator.HOST_REAL_UNIT_NORM_ALLOWANCE,
		"active_task_axes_orthogonal_within_r10e_allowance":
		(
			absf(_dot_v1(active_forward, active_lateral))
			<= R10eScalarValidator.HOST_REAL_UNIT_NORM_ALLOWANCE
		),
		"baseline_forward_axis_unit_within_r10e_allowance":
		absf(_norm_v1(baseline_forward) - 1.0) <= R10eScalarValidator.HOST_REAL_UNIT_NORM_ALLOWANCE,
		"baseline_lateral_axis_unit_within_r10e_allowance":
		absf(_norm_v1(baseline_lateral) - 1.0) <= R10eScalarValidator.HOST_REAL_UNIT_NORM_ALLOWANCE,
		"baseline_task_axes_orthogonal_within_r10e_allowance":
		(
			absf(_dot_v1(baseline_forward, baseline_lateral))
			<= R10eScalarValidator.HOST_REAL_UNIT_NORM_ALLOWANCE
		),
		"paired_forward_axes_link_in_r10e_scalar_space":
		_all_components_within_r10e_allowance_v1(
			_normalize_v1(active_forward), _normalize_v1(baseline_forward)
		),
		"paired_lateral_axes_link_in_r10e_scalar_space":
		_all_components_within_r10e_allowance_v1(
			_normalize_v1(active_lateral), _normalize_v1(baseline_lateral)
		),
		"active_world_impulse_links_to_prefix_lateral_axis":
		_all_components_within_r10e_allowance_v1(active_impulse, recomputed_world_impulse),
		"active_world_impulse_magnitude_within_r10e_allowance":
		(
			absf(_norm_v1(active_impulse) - R10eScalarValidator.EXPECTED_IMPULSE_MAGNITUDE_N_S)
			<= R10eScalarValidator.WORLD_IMPULSE_MAGNITUDE_ALLOWANCE_N_S
		),
		"paired_native_effect_meets_frozen_floor":
		paired_delta_magnitude >= NATIVE_EFFECT_FLOOR_M_S,
	}
	var failed_predicates: Array = []
	for predicate_value in predicates.keys():
		var predicate := String(predicate_value)
		if not bool(predicates[predicate]):
			failed_predicates.append(predicate)
	var computed_measurements := {
		"task_frame_impulse_n_s": [0.0, 0.0, R10eScalarValidator.EXPECTED_IMPULSE_MAGNITUDE_N_S],
		"active_world_impulse_magnitude_n_s": _norm_v1(active_impulse),
		"active_velocity_delta_world_m_s": active_delta,
		"active_velocity_delta_magnitude_m_s": active_delta_magnitude,
		"baseline_velocity_delta_world_m_s": baseline_delta,
		"baseline_velocity_delta_magnitude_m_s": baseline_delta_magnitude,
		"paired_kick_effect_delta_world_m_s": paired_delta,
		"paired_kick_effect_magnitude_m_s": paired_delta_magnitude,
		"native_effect_floor_m_s": NATIVE_EFFECT_FLOOR_M_S,
		"matched_no_kick_delta_subtracted": true,
		"magnitude_replay_operation": R10eScalarValidator.OBSERVED_DELTA_MAGNITUDE_REPLAY_OPERATION,
	}
	if not failed_predicates.is_empty():
		var failure := _failure("QSDK_R10F_IMPULSE_PAIR_PREDICATE_FAILED")
		failure["predicates"] = predicates
		failure["failed_predicates"] = failed_predicates
		failure["computed_measurements"] = computed_measurements
		return failure
	return {
		"ok": true,
		"predicates": predicates,
		"failed_predicates": [],
		"predicate_count": predicates.size(),
		"computed_measurements": computed_measurements,
	}


static func _all_components_within_r10e_allowance_v1(actual: Array, expected: Array) -> bool:
	if actual.size() != 3 or expected.size() != 3:
		return false
	for component_index in range(3):
		var actual_component := float(actual[component_index])
		var expected_component := float(expected[component_index])
		if (
			absf(actual_component - expected_component)
			> R10eScalarValidator.binary64_transport_allowance(actual_component, expected_component)
		):
			return false
	return true


static func _finite_components_v1(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != 3:
		return []
	var result: Array = []
	for component_value in value:
		if typeof(component_value) not in [TYPE_FLOAT, TYPE_INT]:
			return []
		var component := float(component_value)
		if not is_finite(component):
			return []
		result.append(component)
	return result


static func _subtract_v1(left: Array, right: Array) -> Array:
	return [
		float(left[0]) - float(right[0]),
		float(left[1]) - float(right[1]),
		float(left[2]) - float(right[2]),
	]


static func _host_real_length_v1(values: Array) -> float:
	return Vector3(float(values[0]), float(values[1]), float(values[2])).length()


static func _norm_v1(values: Array) -> float:
	return sqrt(_dot_v1(values, values))


static func _dot_v1(left: Array, right: Array) -> float:
	return (
		float(left[0]) * float(right[0])
		+ float(left[1]) * float(right[1])
		+ float(left[2]) * float(right[2])
	)


static func _normalize_v1(values: Array) -> Array:
	var length := _norm_v1(values)
	if not is_finite(length) or length <= 0.0:
		return []
	return [
		float(values[0]) / length,
		float(values[1]) / length,
		float(values[2]) / length,
	]


static func _payload_sha256_v1(sdk: Object, value: Dictionary) -> String:
	var payload := value.duplicate(true)
	payload.erase("payload_sha256")
	var digest := String(RecoveryRuntimeScript.canonicalize(sdk, payload).get("sha256", ""))
	return digest if _digest_valid_v1(digest) else ""


static func _keys_exact_v1(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true


static func _digest_valid_v1(value: String) -> bool:
	return value.begins_with("sha256:") and value.length() == 71


static func _failure(code: String) -> Dictionary:
	return {
		"schema_version": FAILURE_SCHEMA,
		"gate_id": GATE_ID,
		"ok": false,
		"failure_code": code,
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
