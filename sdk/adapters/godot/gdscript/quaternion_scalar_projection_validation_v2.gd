class_name SporeQuaternionScalarProjectionValidationV2
extends RefCounted

## Serialization-stable validator for v1 quaternion projection receipts.
##
## Structure, provenance, authority fields, input components, and the retained
## row link remain exact. Only recomputed derived floating fields use the
## prospectively operation-bounded binary64 comparison. This module does not
## change the projection algorithm or either quaternion unit threshold.

const ProjectionScript := preload(
	"res://sdk/adapters/godot/gdscript/quaternion_scalar_projection_v1.gd"
)
const ScalarValidationScript := preload(
	"res://sdk/adapters/godot/gdscript/exported_scalar_validation_v1.gd"
)

const VALIDATION_SCHEMA := "sporespore_quaternion_scalar_projection_validation_v2"
const STATIC_FIELDS := [
	"schema_version",
	"ok",
	"support_status",
	"refusal_reason",
	"projection_method_id",
	"qualified_precedent_gate_id",
	"qualified_precedent_contract_sha256",
	"reconstructed_component_index",
	"core_norm_squared_tolerance",
	"within_core_unit_contract",
	"model_construction_count",
	"world_attempt_count",
	"world_build_count",
	"native_readback_count",
	"solver_step_count",
	"physics_state_modified",
	"physical_acceptance_authority",
	"release_authority",
]
const DERIVED_SCALAR_FIELDS := [
	"source_norm_squared",
	"source_norm",
	"source_norm_squared_delta",
	"source_norm_delta",
	"projected_norm_squared",
	"projected_norm",
	"projected_norm_squared_delta",
	"projected_norm_delta",
]
const EXPECTED_KEY_COUNT := 28
const EXPECTED_NUMERIC_COMPARISON_COUNT := 12


static func validate_projection_receipt_v2(
	receipt_value: Variant,
	orientation_value: Variant,
) -> Dictionary:
	if typeof(receipt_value) != TYPE_DICTIONARY:
		return _failure("projection_receipt_not_object")
	var receipt: Dictionary = receipt_value
	var source := ScalarValidationScript.finite_components_v1(
		receipt.get("source_orientation_xyzw", null), 4
	)
	if source.size() != 4:
		return _failure("source_orientation_invalid")
	var expected := ProjectionScript.project_components_to_unit_scalar_v1(source)
	if not bool(expected.get("ok", false)):
		return _failure("source_projection_refused")
	if not _same_key_set(receipt, expected):
		return _failure("projection_receipt_key_set_mismatch")
	for field_value in STATIC_FIELDS:
		var field := String(field_value)
		if receipt[field] != expected[field]:
			return _failure("projection_receipt_static_field_mismatch", field)
	if receipt["source_orientation_xyzw"] != expected["source_orientation_xyzw"]:
		return _failure("projection_receipt_source_orientation_mismatch")
	if receipt["orientation_xyzw"] != orientation_value:
		return _failure("projection_receipt_row_orientation_link_mismatch")

	var numeric_comparison_count := 0
	var maximum_absolute_delta := 0.0
	var maximum_allowance := 0.0
	for field_value in DERIVED_SCALAR_FIELDS:
		var field := String(field_value)
		var actual: Variant = receipt[field]
		var expected_value: Variant = expected[field]
		var comparison := _compare_scalar(actual, expected_value)
		if not bool(comparison.get("ok", false)):
			return _failure("projection_receipt_numeric_field_mismatch", field, comparison)
		numeric_comparison_count += 1
		maximum_absolute_delta = maxf(maximum_absolute_delta, float(comparison["absolute_delta"]))
		maximum_allowance = maxf(maximum_allowance, float(comparison["allowance"]))

	var actual_orientation := ScalarValidationScript.finite_float_components_v1(
		receipt["orientation_xyzw"], 4
	)
	var expected_orientation := ScalarValidationScript.finite_float_components_v1(
		expected["orientation_xyzw"], 4
	)
	if actual_orientation.size() != 4 or expected_orientation.size() != 4:
		return _failure("projection_receipt_projected_orientation_invalid")
	for component_index in range(4):
		var comparison := _compare_scalar(
			actual_orientation[component_index], expected_orientation[component_index]
		)
		if not bool(comparison.get("ok", false)):
			return _failure(
				"projection_receipt_orientation_component_mismatch",
				"orientation_xyzw[%d]" % component_index,
				comparison,
			)
		numeric_comparison_count += 1
		maximum_absolute_delta = maxf(maximum_absolute_delta, float(comparison["absolute_delta"]))
		maximum_allowance = maxf(maximum_allowance, float(comparison["allowance"]))
	if numeric_comparison_count != EXPECTED_NUMERIC_COMPARISON_COUNT:
		return _failure("projection_receipt_numeric_comparison_count_mismatch")
	return {
		"schema_version": VALIDATION_SCHEMA,
		"ok": true,
		"failure_code": "",
		"failure_field": "",
		"required_key_set_exact": true,
		"static_field_comparison_count": STATIC_FIELDS.size(),
		"source_orientation_exact": true,
		"row_orientation_link_exact": true,
		"numeric_comparison_count": numeric_comparison_count,
		"maximum_absolute_delta": maximum_absolute_delta,
		"maximum_representation_allowance": maximum_allowance,
		"numeric_contract_id": ScalarValidationScript.CONTRACT_ID,
		"operation_event_budget": int(ScalarValidationScript.OPERATION_EVENT_BUDGET),
		"whole_dictionary_equality_used": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func projection_receipt_matches_orientation_v2(
	receipt_value: Variant,
	orientation_value: Variant,
) -> bool:
	return bool(validate_projection_receipt_v2(receipt_value, orientation_value).get("ok", false))


static func _same_key_set(actual: Dictionary, expected: Dictionary) -> bool:
	if actual.size() != EXPECTED_KEY_COUNT or expected.size() != EXPECTED_KEY_COUNT:
		return false
	for key in expected:
		if not actual.has(key):
			return false
	for key in actual:
		if not expected.has(key):
			return false
	return true


static func _compare_scalar(actual: Variant, expected: Variant) -> Dictionary:
	var allowance: Variant = ScalarValidationScript.representation_allowance_v1(actual, expected)
	if allowance == null:
		return {"ok": false, "absolute_delta": null, "allowance": null}
	var absolute_delta := absf(float(actual) - float(expected))
	return {
		"ok": absolute_delta <= float(allowance),
		"absolute_delta": absolute_delta,
		"allowance": allowance,
	}


static func _failure(
	code: String,
	field: String = "",
	detail: Dictionary = {},
) -> Dictionary:
	return {
		"schema_version": VALIDATION_SCHEMA,
		"ok": false,
		"failure_code": code,
		"failure_field": field,
		"detail": detail.duplicate(true),
		"required_key_set_exact": true,
		"whole_dictionary_equality_used": false,
		"numeric_contract_id": ScalarValidationScript.CONTRACT_ID,
		"operation_event_budget": int(ScalarValidationScript.OPERATION_EVENT_BUDGET),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
