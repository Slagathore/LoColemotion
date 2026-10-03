class_name SporeQuaternionScalarProjectionV1
extends RefCounted

## Pure Godot real_t -> exported-scalar quaternion projection.
##
## This is the lightweight reusable form of the representation method first
## qualified by QSDK-R24D66. It does not construct a model or world, read native
## state, or modify physics. The four host components are promoted into GDScript
## scalar values, normalized there, and the largest absolute component is
## reconstructed from the other three. That last step prevents a unit
## quaternion from becoming observably non-unit solely because float32 host
## components were serialized as binary64 JSON numbers.

const PROJECTION_SCHEMA := "sporespore_godot_quaternion_scalar_projection_v1"
const DIAGNOSTIC_SCHEMA := "sporespore_godot_quaternion_scalar_diagnostic_v1"
const METHOD_ID := "godot_real_t_to_float64_largest_component_unit_reconstruction_v1"
const QUALIFIED_PRECEDENT_GATE_ID := "QSDK-R24D66"
const QUALIFIED_PRECEDENT_CONTRACT_SHA256 := "sha256:2860d75b05bf5ae1662ef73bf9585915b997e760ee392b8ba98c4b7f45665ece"
const CORE_NORM_SQUARED_TOLERANCE := 1.0e-9


static func project_quaternion_to_unit_scalar_v1(value: Quaternion) -> Dictionary:
	return project_components_to_unit_scalar_v1(
		[
			float(value.x),
			float(value.y),
			float(value.z),
			float(value.w),
		]
	)


static func project_components_to_unit_scalar_v1(value: Variant) -> Dictionary:
	var source_result := _components_v1(value)
	var source: Array = source_result["components"]
	if not bool(source_result.get("ok", false)):
		return _projection_failure_v1("invalid_source_components", source, null)
	var source_norm_squared := _norm_squared_v1(source)
	if not is_finite(source_norm_squared) or source_norm_squared <= 0.0:
		return _projection_failure_v1(
			"nonpositive_source_norm_squared", source, source_norm_squared
		)
	var source_norm := sqrt(source_norm_squared)
	if not is_finite(source_norm) or source_norm <= 0.0:
		return _projection_failure_v1("invalid_source_norm", source, source_norm_squared)

	var projected: Array = []
	for component in source:
		projected.append(float(component) / source_norm)
	var reconstructed_component_index := 0
	for index in range(1, projected.size()):
		if absf(float(projected[index])) > absf(float(projected[reconstructed_component_index])):
			reconstructed_component_index = index
	var other_component_norm_squared := 0.0
	for index in range(projected.size()):
		if index != reconstructed_component_index:
			other_component_norm_squared += float(projected[index]) * float(projected[index])
	var reconstructed_squared := 1.0 - other_component_norm_squared
	if not is_finite(reconstructed_squared) or reconstructed_squared < -CORE_NORM_SQUARED_TOLERANCE:
		return _projection_failure_v1(
			"largest_component_reconstruction_invalid", source, source_norm_squared
		)
	var sign_value := -1.0 if float(source[reconstructed_component_index]) < 0.0 else 1.0
	projected[reconstructed_component_index] = sign_value * sqrt(maxf(0.0, reconstructed_squared))
	var projected_norm_squared := _norm_squared_v1(projected)
	var projected_norm_squared_delta := absf(projected_norm_squared - 1.0)
	if (
		not is_finite(projected_norm_squared)
		or projected_norm_squared_delta > CORE_NORM_SQUARED_TOLERANCE
	):
		return _projection_failure_v1(
			"projected_norm_outside_core_contract", source, source_norm_squared
		)
	return {
		"schema_version": PROJECTION_SCHEMA,
		"ok": true,
		"support_status": "supported_exact",
		"refusal_reason": null,
		"projection_method_id": METHOD_ID,
		"qualified_precedent_gate_id": QUALIFIED_PRECEDENT_GATE_ID,
		"qualified_precedent_contract_sha256": QUALIFIED_PRECEDENT_CONTRACT_SHA256,
		"source_orientation_xyzw": source.duplicate(),
		"source_norm_squared": source_norm_squared,
		"source_norm": source_norm,
		"source_norm_squared_delta": absf(source_norm_squared - 1.0),
		"source_norm_delta": absf(source_norm - 1.0),
		"orientation_xyzw": projected.duplicate(),
		"projected_norm_squared": projected_norm_squared,
		"projected_norm": sqrt(projected_norm_squared),
		"projected_norm_squared_delta": projected_norm_squared_delta,
		"projected_norm_delta": absf(sqrt(projected_norm_squared) - 1.0),
		"reconstructed_component_index": reconstructed_component_index,
		"core_norm_squared_tolerance": CORE_NORM_SQUARED_TOLERANCE,
		"within_core_unit_contract": true,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func diagnose_orientation_xyzw_v1(value: Variant) -> Dictionary:
	var source_result := _components_v1(value)
	var source: Array = source_result["components"]
	var finite_components := bool(source_result.get("ok", false))
	var norm_squared: Variant = null
	var norm: Variant = null
	var norm_squared_delta: Variant = null
	var norm_delta: Variant = null
	if finite_components:
		norm_squared = _norm_squared_v1(source)
		if is_finite(float(norm_squared)) and float(norm_squared) >= 0.0:
			norm = sqrt(float(norm_squared))
			norm_squared_delta = absf(float(norm_squared) - 1.0)
			norm_delta = absf(float(norm) - 1.0)
	return {
		"schema_version": DIAGNOSTIC_SCHEMA,
		"ok": finite_components and norm != null and is_finite(float(norm)),
		"orientation_xyzw": source.duplicate(),
		"norm_squared": norm_squared,
		"norm": norm,
		"norm_squared_delta": norm_squared_delta,
		"norm_delta": norm_delta,
		"core_norm_squared_tolerance": CORE_NORM_SQUARED_TOLERANCE,
		"within_core_norm_squared_contract":
		(
			finite_components
			and norm_squared_delta != null
			and float(norm_squared_delta) <= CORE_NORM_SQUARED_TOLERANCE
		),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func projection_receipt_matches_orientation_v1(
	receipt_value: Variant,
	orientation_value: Variant,
) -> bool:
	if typeof(receipt_value) != TYPE_DICTIONARY:
		return false
	var receipt: Dictionary = receipt_value
	var source_value: Variant = receipt.get("source_orientation_xyzw", null)
	var expected := project_components_to_unit_scalar_v1(source_value)
	return (
		bool(expected.get("ok", false))
		and receipt == expected
		and receipt.get("orientation_xyzw", null) == orientation_value
	)


static func _components_v1(value: Variant) -> Dictionary:
	var components: Array = []
	if typeof(value) == TYPE_ARRAY and (value as Array).size() == 4:
		for component in value as Array:
			if typeof(component) not in [TYPE_FLOAT, TYPE_INT]:
				return {"ok": false, "components": components}
			var numeric := float(component)
			if not is_finite(numeric):
				return {"ok": false, "components": components}
			components.append(numeric)
	return {"ok": components.size() == 4, "components": components}


static func _norm_squared_v1(components: Array) -> float:
	var norm_squared := 0.0
	for component in components:
		norm_squared += float(component) * float(component)
	return norm_squared


static func _projection_failure_v1(
	reason: String,
	source_components: Array,
	source_norm_squared: Variant,
) -> Dictionary:
	var source_norm: Variant = null
	var source_norm_squared_delta: Variant = null
	var source_norm_delta: Variant = null
	if source_norm_squared != null and is_finite(float(source_norm_squared)):
		source_norm_squared_delta = absf(float(source_norm_squared) - 1.0)
		if float(source_norm_squared) >= 0.0:
			source_norm = sqrt(float(source_norm_squared))
			source_norm_delta = absf(float(source_norm) - 1.0)
	return {
		"schema_version": PROJECTION_SCHEMA,
		"ok": false,
		"support_status": "invalid_quaternion_projection",
		"refusal_reason": reason,
		"projection_method_id": METHOD_ID,
		"qualified_precedent_gate_id": QUALIFIED_PRECEDENT_GATE_ID,
		"qualified_precedent_contract_sha256": QUALIFIED_PRECEDENT_CONTRACT_SHA256,
		"source_orientation_xyzw": source_components.duplicate(),
		"source_norm_squared": source_norm_squared,
		"source_norm": source_norm,
		"source_norm_squared_delta": source_norm_squared_delta,
		"source_norm_delta": source_norm_delta,
		"orientation_xyzw": null,
		"projected_norm_squared": null,
		"projected_norm": null,
		"projected_norm_squared_delta": null,
		"projected_norm_delta": null,
		"reconstructed_component_index": null,
		"core_norm_squared_tolerance": CORE_NORM_SQUARED_TOLERANCE,
		"within_core_unit_contract": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
