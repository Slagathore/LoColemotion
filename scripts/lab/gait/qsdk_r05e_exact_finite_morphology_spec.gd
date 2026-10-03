class_name LabQsdkR05eExactFiniteMorphologySpec
extends RefCounted

## Exact, zero-world descriptor authority for QSDK-R05E.
##
## This source intentionally contains no sampler. Each accepted generator index
## names one frozen descriptor. Indices 217 through 228 are the held-out finite
## decision; index 229 is the separately classified development route ghost.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const PROPORTION_SPEC_SCHEMA_VERSION := "sporespore_physical_quadruped_proportion_spec_v1"
const AXIS_STAR_SCHEMA_VERSION := "sporespore_qsdk_r05e_exact_finite_axis_star_v1"
const GENERATOR_POLICY_ID := "qsdk_r05e_exact_finite_axis_star_v1"
const GENERATOR_SCHEMA_VERSION := "sporespore_qsdk_r05e_exact_finite_generation_receipt_v1"
const OFFICIAL_CAMPAIGN_ID := "QSDK-R05E-EXACT-FINITE-MORPHOLOGY-VALIDATION"
const DEVELOPMENT_GHOST_CAMPAIGN_ID := "QSDK-R05E-DEVELOPMENT-ROUTE-GHOST"
const OFFICIAL_INDICES := [217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228]
const DEVELOPMENT_GHOST_INDEX := 229
const ALL_INDICES := [217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229]
const AXIS_KEYS := [
	"torso_length_scale",
	"torso_width_scale",
	"upper_length_fraction",
	"hip_span_scale",
	"foot_radius_scale",
	"front_limb_mass_scale",
]
const CELL_DEFINITION_KEYS := ["changed_axis", "direction", "proportion_spec"]
const CELL_ENTRY_KEYS := [
	"generator_index",
	"morphology_id",
	"generator_receipt_sha256",
	"proportion_spec_sha256",
]
const PROPORTION_SPEC_KEYS := [
	"schema_version",
	"morphology_id",
	"torso_length_scale",
	"torso_width_scale",
	"upper_length_fraction",
	"hip_span_scale",
	"foot_radius_scale",
	"front_limb_mass_scale",
]
const REFERENCE := {
	"torso_length_scale": 1.0,
	"torso_width_scale": 1.0,
	"upper_length_fraction": 0.5142857142857142,
	"hip_span_scale": 1.0,
	"foot_radius_scale": 1.0,
	"front_limb_mass_scale": 1.0,
}
const HISTORICAL_INTERVALS := {
	"torso_length_scale": [0.9, 1.1],
	"torso_width_scale": [0.9, 1.1],
	"upper_length_fraction": [0.5, 0.55],
	"hip_span_scale": [0.9, 1.1],
	"foot_radius_scale": [0.975, 1.1],
	"front_limb_mass_scale": [0.9, 1.05],
}
const CELL_BY_INDEX := {
	217: {
		"changed_axis": "torso_length_scale",
		"direction": "low",
		"proportion_spec": {
			"schema_version": PROPORTION_SPEC_SCHEMA_VERSION,
			"morphology_id": "qsdk_r05e_axis_star_torso_length_low_s217",
			"torso_length_scale": 0.975,
			"torso_width_scale": 1.0,
			"upper_length_fraction": 0.5142857142857142,
			"hip_span_scale": 1.0,
			"foot_radius_scale": 1.0,
			"front_limb_mass_scale": 1.0,
		},
	},
	218: {
		"changed_axis": "torso_length_scale",
		"direction": "high",
		"proportion_spec": {
			"schema_version": PROPORTION_SPEC_SCHEMA_VERSION,
			"morphology_id": "qsdk_r05e_axis_star_torso_length_high_s218",
			"torso_length_scale": 1.025,
			"torso_width_scale": 1.0,
			"upper_length_fraction": 0.5142857142857142,
			"hip_span_scale": 1.0,
			"foot_radius_scale": 1.0,
			"front_limb_mass_scale": 1.0,
		},
	},
	219: {
		"changed_axis": "torso_width_scale",
		"direction": "low",
		"proportion_spec": {
			"schema_version": PROPORTION_SPEC_SCHEMA_VERSION,
			"morphology_id": "qsdk_r05e_axis_star_torso_width_low_s219",
			"torso_length_scale": 1.0,
			"torso_width_scale": 0.975,
			"upper_length_fraction": 0.5142857142857142,
			"hip_span_scale": 1.0,
			"foot_radius_scale": 1.0,
			"front_limb_mass_scale": 1.0,
		},
	},
	220: {
		"changed_axis": "torso_width_scale",
		"direction": "high",
		"proportion_spec": {
			"schema_version": PROPORTION_SPEC_SCHEMA_VERSION,
			"morphology_id": "qsdk_r05e_axis_star_torso_width_high_s220",
			"torso_length_scale": 1.0,
			"torso_width_scale": 1.025,
			"upper_length_fraction": 0.5142857142857142,
			"hip_span_scale": 1.0,
			"foot_radius_scale": 1.0,
			"front_limb_mass_scale": 1.0,
		},
	},
	221: {
		"changed_axis": "upper_length_fraction",
		"direction": "low",
		"proportion_spec": {
			"schema_version": PROPORTION_SPEC_SCHEMA_VERSION,
			"morphology_id": "qsdk_r05e_axis_star_upper_fraction_low_s221",
			"torso_length_scale": 1.0,
			"torso_width_scale": 1.0,
			"upper_length_fraction": 0.5107142857142857,
			"hip_span_scale": 1.0,
			"foot_radius_scale": 1.0,
			"front_limb_mass_scale": 1.0,
		},
	},
	222: {
		"changed_axis": "upper_length_fraction",
		"direction": "high",
		"proportion_spec": {
			"schema_version": PROPORTION_SPEC_SCHEMA_VERSION,
			"morphology_id": "qsdk_r05e_axis_star_upper_fraction_high_s222",
			"torso_length_scale": 1.0,
			"torso_width_scale": 1.0,
			"upper_length_fraction": 0.5232142857142856,
			"hip_span_scale": 1.0,
			"foot_radius_scale": 1.0,
			"front_limb_mass_scale": 1.0,
		},
	},
	223: {
		"changed_axis": "hip_span_scale",
		"direction": "low",
		"proportion_spec": {
			"schema_version": PROPORTION_SPEC_SCHEMA_VERSION,
			"morphology_id": "qsdk_r05e_axis_star_hip_span_low_s223",
			"torso_length_scale": 1.0,
			"torso_width_scale": 1.0,
			"upper_length_fraction": 0.5142857142857142,
			"hip_span_scale": 0.975,
			"foot_radius_scale": 1.0,
			"front_limb_mass_scale": 1.0,
		},
	},
	224: {
		"changed_axis": "hip_span_scale",
		"direction": "high",
		"proportion_spec": {
			"schema_version": PROPORTION_SPEC_SCHEMA_VERSION,
			"morphology_id": "qsdk_r05e_axis_star_hip_span_high_s224",
			"torso_length_scale": 1.0,
			"torso_width_scale": 1.0,
			"upper_length_fraction": 0.5142857142857142,
			"hip_span_scale": 1.025,
			"foot_radius_scale": 1.0,
			"front_limb_mass_scale": 1.0,
		},
	},
	225: {
		"changed_axis": "foot_radius_scale",
		"direction": "low",
		"proportion_spec": {
			"schema_version": PROPORTION_SPEC_SCHEMA_VERSION,
			"morphology_id": "qsdk_r05e_axis_star_foot_radius_low_s225",
			"torso_length_scale": 1.0,
			"torso_width_scale": 1.0,
			"upper_length_fraction": 0.5142857142857142,
			"hip_span_scale": 1.0,
			"foot_radius_scale": 0.99375,
			"front_limb_mass_scale": 1.0,
		},
	},
	226: {
		"changed_axis": "foot_radius_scale",
		"direction": "high",
		"proportion_spec": {
			"schema_version": PROPORTION_SPEC_SCHEMA_VERSION,
			"morphology_id": "qsdk_r05e_axis_star_foot_radius_high_s226",
			"torso_length_scale": 1.0,
			"torso_width_scale": 1.0,
			"upper_length_fraction": 0.5142857142857142,
			"hip_span_scale": 1.0,
			"foot_radius_scale": 1.025,
			"front_limb_mass_scale": 1.0,
		},
	},
	227: {
		"changed_axis": "front_limb_mass_scale",
		"direction": "low",
		"proportion_spec": {
			"schema_version": PROPORTION_SPEC_SCHEMA_VERSION,
			"morphology_id": "qsdk_r05e_axis_star_front_limb_mass_low_s227",
			"torso_length_scale": 1.0,
			"torso_width_scale": 1.0,
			"upper_length_fraction": 0.5142857142857142,
			"hip_span_scale": 1.0,
			"foot_radius_scale": 1.0,
			"front_limb_mass_scale": 0.975,
		},
	},
	228: {
		"changed_axis": "front_limb_mass_scale",
		"direction": "high",
		"proportion_spec": {
			"schema_version": PROPORTION_SPEC_SCHEMA_VERSION,
			"morphology_id": "qsdk_r05e_axis_star_front_limb_mass_high_s228",
			"torso_length_scale": 1.0,
			"torso_width_scale": 1.0,
			"upper_length_fraction": 0.5142857142857142,
			"hip_span_scale": 1.0,
			"foot_radius_scale": 1.0,
			"front_limb_mass_scale": 1.0125,
		},
	},
	229: {
		"changed_axis": "torso_length_scale",
		"direction": "mid_high_development_ghost",
		"proportion_spec": {
			"schema_version": PROPORTION_SPEC_SCHEMA_VERSION,
			"morphology_id": "qsdk_r05d_development_ghost_torso_length_mid_high_s229",
			"torso_length_scale": 1.0125,
			"torso_width_scale": 1.0,
			"upper_length_fraction": 0.5142857142857142,
			"hip_span_scale": 1.0,
			"foot_radius_scale": 1.0,
			"front_limb_mass_scale": 1.0,
		},
	},
}


static func compile_generation(generator_index_value: Variant) -> Dictionary:
	if typeof(generator_index_value) != TYPE_INT:
		return _failure("INVALID_QSDK_R05E_GENERATOR_INDEX_TYPE")
	var generator_index := int(generator_index_value)
	if not ALL_INDICES.has(generator_index):
		return _failure("UNKNOWN_QSDK_R05E_GENERATOR_INDEX", generator_index)
	var cell: Dictionary = (CELL_BY_INDEX[generator_index] as Dictionary).duplicate(true)
	var proportion_spec: Dictionary = cell["proportion_spec"]
	if not _proportion_spec_shape_exact(generator_index, cell, proportion_spec):
		return _failure("QSDK_R05E_INTERNAL_DESCRIPTOR_INVALID", generator_index)
	var campaign_role := (
		"held_out_finite_decision"
		if OFFICIAL_INDICES.has(generator_index)
		else "development_route_ghost"
	)
	var campaign_id := (
		OFFICIAL_CAMPAIGN_ID
		if OFFICIAL_INDICES.has(generator_index)
		else DEVELOPMENT_GHOST_CAMPAIGN_ID
	)
	var generator_receipt := {
		"schema_version": GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": GENERATOR_POLICY_ID,
		"axis_star_schema_version": AXIS_STAR_SCHEMA_VERSION,
		"campaign_id": campaign_id,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"changed_axis": String(cell["changed_axis"]),
		"direction": String(cell["direction"]),
		"proportion_spec": proportion_spec.duplicate(true),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physical_acceptance_authority": false,
	}
	return {
		"ok": true,
		"failure_code": "",
		"campaign_role": campaign_role,
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
		"proportion_spec": proportion_spec.duplicate(true),
		"proportion_spec_sha256": CanonicalJsonScript.sha256(proportion_spec),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physical_acceptance_authority": false,
	}


static func verify_generation(
	generator_index_value: Variant,
	expected_generator_receipt_sha256: String,
	expected_proportion_spec_sha256: String,
) -> Dictionary:
	var result := compile_generation(generator_index_value)
	if not bool(result.get("ok", false)):
		return result
	if (
		expected_generator_receipt_sha256.is_empty()
		or String(result["generator_receipt_sha256"]) != expected_generator_receipt_sha256
		or expected_proportion_spec_sha256.is_empty()
		or String(result["proportion_spec_sha256"]) != expected_proportion_spec_sha256
	):
		return _failure("QSDK_R05E_GENERATION_DIGEST_MISMATCH", int(generator_index_value))
	return result


static func validate_exact_proportion_spec(
	generator_index_value: Variant,
	candidate_value: Variant,
) -> Dictionary:
	var generated := compile_generation(generator_index_value)
	if not bool(generated.get("ok", false)):
		return generated
	if typeof(candidate_value) != TYPE_DICTIONARY:
		return _failure("QSDK_R05E_DESCRIPTOR_NOT_OBJECT", int(generator_index_value))
	var candidate: Dictionary = candidate_value
	var expected: Dictionary = generated["proportion_spec"]
	if CanonicalJsonScript.sha256(candidate) != CanonicalJsonScript.sha256(expected):
		return _failure("QSDK_R05E_DESCRIPTOR_NOT_EXACT", int(generator_index_value))
	return {
		"ok": true,
		"failure_code": "",
		"generator_index": int(generator_index_value),
		"proportion_spec_sha256": CanonicalJsonScript.sha256(candidate),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physical_acceptance_authority": false,
	}


static func validate_exact_cell_set(
	cells_value: Variant,
	expected_indices: Array,
) -> Dictionary:
	if typeof(cells_value) != TYPE_ARRAY:
		return _failure("QSDK_R05E_CELL_SET_NOT_ARRAY")
	if not (
		_integer_array_exact(expected_indices, OFFICIAL_INDICES)
		or _integer_array_exact(expected_indices, [DEVELOPMENT_GHOST_INDEX])
	):
		return _failure("QSDK_R05E_EXPECTED_INDEX_SET_INVALID")
	var cells: Array = cells_value
	if cells.size() != expected_indices.size():
		return _failure("QSDK_R05E_CELL_SET_COUNT_MISMATCH")
	var seen_indices := {}
	var seen_morphology_ids := {}
	for ordinal in range(cells.size()):
		if typeof(cells[ordinal]) != TYPE_DICTIONARY:
			return _failure("QSDK_R05E_CELL_NOT_OBJECT")
		var cell: Dictionary = cells[ordinal]
		if not _dictionary_keys_exact(cell, CELL_ENTRY_KEYS):
			return _failure("QSDK_R05E_CELL_SHAPE_INVALID")
		var generator_index_value: Variant = cell.get("generator_index")
		if typeof(generator_index_value) != TYPE_INT:
			return _failure("QSDK_R05E_CELL_INDEX_NOT_INT")
		var generator_index := int(generator_index_value)
		if generator_index != int(expected_indices[ordinal]) or seen_indices.has(generator_index):
			return _failure("QSDK_R05E_CELL_INDEX_DUPLICATE_OR_OUT_OF_ORDER", generator_index)
		var generated := compile_generation(generator_index)
		if not bool(generated.get("ok", false)):
			return generated
		if (
			typeof(cell.get("morphology_id")) != TYPE_STRING
			or typeof(cell.get("generator_receipt_sha256")) != TYPE_STRING
			or typeof(cell.get("proportion_spec_sha256")) != TYPE_STRING
		):
			return _failure("QSDK_R05E_CELL_FIELD_TYPE_INVALID", generator_index)
		var morphology_id: String = cell["morphology_id"]
		var expected_spec: Dictionary = generated["proportion_spec"]
		if morphology_id != String(expected_spec["morphology_id"]) or seen_morphology_ids.has(morphology_id):
			return _failure("QSDK_R05E_MORPHOLOGY_ID_DUPLICATE_OR_MISMATCH", generator_index)
		if (
			String(cell.get("generator_receipt_sha256", ""))
			!= String(generated["generator_receipt_sha256"])
			or String(cell.get("proportion_spec_sha256", ""))
			!= String(generated["proportion_spec_sha256"])
		):
			return _failure("QSDK_R05E_CELL_DIGEST_MISMATCH", generator_index)
		seen_indices[generator_index] = true
		seen_morphology_ids[morphology_id] = true
	return {
		"ok": true,
		"failure_code": "",
		"cell_count": cells.size(),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physical_acceptance_authority": false,
	}


static func official_cells() -> Array:
	return _compiled_cells(OFFICIAL_INDICES)


static func development_ghost_cells() -> Array:
	return _compiled_cells([DEVELOPMENT_GHOST_INDEX])


static func _compiled_cells(indices: Array) -> Array:
	var cells: Array = []
	for generator_index in indices:
		var result := compile_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func _proportion_spec_shape_exact(
	generator_index: int,
	cell: Dictionary,
	proportion_spec: Dictionary,
) -> bool:
	if (
		not _dictionary_keys_exact(cell, CELL_DEFINITION_KEYS)
		or not _dictionary_keys_exact(proportion_spec, PROPORTION_SPEC_KEYS)
		or typeof(cell.get("changed_axis")) != TYPE_STRING
		or typeof(cell.get("direction")) != TYPE_STRING
		or typeof(proportion_spec.get("schema_version")) != TYPE_STRING
		or typeof(proportion_spec.get("morphology_id")) != TYPE_STRING
		or String(proportion_spec["schema_version"]) != PROPORTION_SPEC_SCHEMA_VERSION
		or String(proportion_spec["morphology_id"]).is_empty()
		or not AXIS_KEYS.has(String(cell["changed_axis"]))
	):
		return false
	var changed_axis_count := 0
	var changed_axis_value := NAN
	for axis_key_value in AXIS_KEYS:
		var axis_key := String(axis_key_value)
		if not proportion_spec.has(axis_key) or typeof(proportion_spec[axis_key]) not in [TYPE_FLOAT, TYPE_INT]:
			return false
		var value := float(proportion_spec[axis_key])
		var interval: Array = HISTORICAL_INTERVALS[axis_key]
		if not is_finite(value) or value < float(interval[0]) or value > float(interval[1]):
			return false
		if value != float(REFERENCE[axis_key]):
			changed_axis_count += 1
			if axis_key != String(cell["changed_axis"]):
				return false
			changed_axis_value = value
	if changed_axis_count != 1 or not ALL_INDICES.has(generator_index):
		return false
	var changed_axis := String(cell["changed_axis"])
	var reference_value := float(REFERENCE[changed_axis])
	if OFFICIAL_INDICES.has(generator_index):
		var expected_direction := "low" if changed_axis_value < reference_value else "high"
		return String(cell["direction"]) == expected_direction
	return (
		generator_index == DEVELOPMENT_GHOST_INDEX
		and String(cell["direction"]) == "mid_high_development_ghost"
		and changed_axis_value > reference_value
	)


static func _integer_array_exact(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for index in range(expected.size()):
		if typeof(actual[index]) != TYPE_INT or int(actual[index]) != int(expected[index]):
			return false
	return true


static func _dictionary_keys_exact(value: Dictionary, expected_keys: Array) -> bool:
	if value.size() != expected_keys.size():
		return false
	for key_value in expected_keys:
		if not value.has(String(key_value)):
			return false
	return true


static func _failure(code: String, generator_index: int = -1) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"generator_index": generator_index,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physical_acceptance_authority": false,
	}
