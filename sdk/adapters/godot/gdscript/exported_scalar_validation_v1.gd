class_name SporeExportedScalarValidationV1
extends RefCounted

## Pure validation helpers for numeric values retained as JSON scalar numbers.
##
## GDScript float values are used directly so validation does not first
## rematerialize retained binary64 numbers through a float32 engine geometry
## type. No function constructs a model or world, reads native state, or
## modifies physics.

const CONTRACT_ID := "binary64_operation_budget_scaled_comparison_v1"
const BINARY64_MACHINE_EPSILON := 2.220446049250313e-16
const OPERATION_EVENT_BUDGET := 32.0
const UNIT_SCALE_REPRESENTATION_ALLOWANCE := 7.105427357601002e-15


static func finite_components_v1(value: Variant, expected_size: int) -> Array:
	if expected_size <= 0 or typeof(value) != TYPE_ARRAY:
		return []
	var source: Array = value
	if source.size() != expected_size:
		return []
	var components: Array = []
	for component in source:
		if typeof(component) not in [TYPE_FLOAT, TYPE_INT]:
			return []
		var numeric := float(component)
		if not is_finite(numeric):
			return []
		components.append(numeric)
	return components


static func finite_float_components_v1(value: Variant, expected_size: int) -> Array:
	if expected_size <= 0 or typeof(value) != TYPE_ARRAY:
		return []
	var source: Array = value
	if source.size() != expected_size:
		return []
	var components: Array = []
	for component in source:
		if typeof(component) != TYPE_FLOAT or not is_finite(float(component)):
			return []
		components.append(float(component))
	return components


static func norm_delta_v1(components: Array) -> float:
	var norm_squared := 0.0
	for component in components:
		norm_squared += float(component) * float(component)
	return absf(sqrt(norm_squared) - 1.0)


static func dot_absolute_v1(left: Array, right: Array) -> float:
	if left.size() != right.size() or left.is_empty():
		return INF
	var dot := 0.0
	for index in range(left.size()):
		dot += float(left[index]) * float(right[index])
	return absf(dot)


static func representation_allowance_v1(actual: Variant, expected: Variant) -> Variant:
	if typeof(actual) != TYPE_FLOAT or typeof(expected) != TYPE_FLOAT:
		return null
	var actual_float := float(actual)
	var expected_float := float(expected)
	if not is_finite(actual_float) or not is_finite(expected_float):
		return null
	return (
		OPERATION_EVENT_BUDGET
		* BINARY64_MACHINE_EPSILON
		* maxf(1.0, maxf(absf(actual_float), absf(expected_float)))
	)


static func representation_equal_v1(actual: Variant, expected: Variant) -> bool:
	var allowance: Variant = representation_allowance_v1(actual, expected)
	return allowance != null and absf(float(actual) - float(expected)) <= float(allowance)
