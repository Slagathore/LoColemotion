extends SceneTree

## Independent, zero-world source and mutation gate for the exact R05E axis star.
##
## This test binds the implementation back to the immutable R05D design and to
## both prospective preregistrations. It compiles descriptors only: no Node,
## model, physics world, native state, or locomotion outcome is constructed.

const ExactSpecScript := preload(
	"res://scripts/lab/gait/qsdk_r05e_exact_finite_morphology_spec.gd"
)
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const DESIGN_PATH := "res://sdk/qsdk_r05d_exact_finite_morphology_successor_design_v1.json"
const OFFICIAL_PREREGISTRATION_PATH := (
	"res://sdk/qsdk_r05e_exact_finite_morphology_preregistration.json"
)
const GHOST_PREREGISTRATION_PATH := (
	"res://sdk/qsdk_r05e_development_route_ghost_preregistration.json"
)
const DESIGN_SHA256 := "3b75b7609b638470ee947326f71018d082beb4a2c2909e78dae77d3b50250a6c"
const OFFICIAL_PREREGISTRATION_SHA256 := (
	"3e51a1b2198740bf3a54198bb6cfdbdc946429fb69528378dba7d25cc2d21895"
)
const GHOST_PREREGISTRATION_SHA256 := (
	"ce1ef34851f81455115dd7031546f867f466c8ce264e375faba6c2d4436cf7f9"
)
const MARKER := "QSDK_R05E_EXACT_FINITE_MORPHOLOGY_SOURCE_ZERO_WORLD "


func _initialize() -> void:
	var receipt := _run()
	print(MARKER, JSON.stringify(receipt, "", true, true))
	quit(0 if bool(receipt.get("ok", false)) else 1)


func _run() -> Dictionary:
	if root.get_child_count() != 0:
		return _failure("QSDK_R05E_SOURCE_GATE_SCENE_TREE_NOT_EMPTY")
	if FileAccess.get_sha256(DESIGN_PATH).to_lower() != DESIGN_SHA256:
		return _failure("QSDK_R05E_SOURCE_GATE_R05D_DESIGN_DIGEST_MISMATCH")
	if (
		FileAccess.get_sha256(OFFICIAL_PREREGISTRATION_PATH).to_lower()
		!= OFFICIAL_PREREGISTRATION_SHA256
	):
		return _failure("QSDK_R05E_SOURCE_GATE_OFFICIAL_PREREGISTRATION_DIGEST_MISMATCH")
	if (
		FileAccess.get_sha256(GHOST_PREREGISTRATION_PATH).to_lower()
		!= GHOST_PREREGISTRATION_SHA256
	):
		return _failure("QSDK_R05E_SOURCE_GATE_GHOST_PREREGISTRATION_DIGEST_MISMATCH")

	var design := _read_json_object(DESIGN_PATH)
	var official_preregistration := _read_json_object(OFFICIAL_PREREGISTRATION_PATH)
	var ghost_preregistration := _read_json_object(GHOST_PREREGISTRATION_PATH)
	if design.is_empty() or official_preregistration.is_empty() or ghost_preregistration.is_empty():
		return _failure("QSDK_R05E_SOURCE_GATE_AUTHORITY_JSON_INVALID")
	if (
		String(design.get("schema_version", ""))
		!= "sporespore_qsdk_r05d_exact_finite_morphology_successor_design_v1"
		or String(official_preregistration.get("schema_version", ""))
		!= "sporespore_qsdk_r05e_exact_finite_morphology_preregistration_v1"
		or String(ghost_preregistration.get("schema_version", ""))
		!= "sporespore_qsdk_r05e_development_route_ghost_preregistration_v1"
	):
		return _failure("QSDK_R05E_SOURCE_GATE_AUTHORITY_SCHEMA_MISMATCH")

	var axis_star: Dictionary = design.get("axis_star", {})
	var reference: Dictionary = axis_star.get("reference", {})
	var historical_intervals: Dictionary = axis_star.get("historical_axis_intervals", {})
	var exact_endpoints: Dictionary = axis_star.get("exact_axis_endpoints", {})
	var design_cells: Array = axis_star.get("cells", [])
	var official_generator: Dictionary = official_preregistration.get("morphology_generator", {})
	var ghost_generator: Dictionary = ghost_preregistration.get("morphology_generator", {})
	var official_records: Array = official_generator.get("cells", [])
	var ghost_records: Array = ghost_generator.get("cells", [])
	if (
		String(axis_star.get("schema_version", "")) != ExactSpecScript.AXIS_STAR_SCHEMA_VERSION
		or int(axis_star.get("cell_count", -1)) != 12
		or design_cells.size() != 12
		or official_records.size() != 12
		or ghost_records.size() != 1
	):
		return _failure("QSDK_R05E_SOURCE_GATE_DECLARED_CELL_POPULATION_MISMATCH")

	var official_specs := ExactSpecScript.official_cells()
	var ghost_specs := ExactSpecScript.development_ghost_cells()
	if official_specs.size() != 12 or ghost_specs.size() != 1:
		return _failure("QSDK_R05E_SOURCE_GATE_COMPILED_CELL_POPULATION_MISMATCH")

	var direction_counts := {}
	for axis_value in ExactSpecScript.AXIS_KEYS:
		direction_counts[String(axis_value)] = {"low": 0, "high": 0}
	var official_ids := {}
	var official_spec_digests := {}
	var official_compiled_records: Array = []
	var altered_coordinate_controls: Array = []
	for ordinal in range(design_cells.size()):
		var expected_cell: Dictionary = design_cells[ordinal]
		var generator_index := int(expected_cell.get("generator_index", -1))
		if generator_index != int(ExactSpecScript.OFFICIAL_INDICES[ordinal]):
			return _failure("QSDK_R05E_SOURCE_GATE_OFFICIAL_INDEX_ORDER_MISMATCH")
		var generated := ExactSpecScript.compile_generation(generator_index)
		if not bool(generated.get("ok", false)) or not _zero_authority(generated):
			return _failure(
				"QSDK_R05E_SOURCE_GATE_OFFICIAL_GENERATION_REFUSED",
				{"generator_index": generator_index, "generated": generated},
			)
		var receipt: Dictionary = generated.get("generator_receipt", {})
		var spec: Dictionary = generated.get("proportion_spec", {})
		var expected_spec: Dictionary = expected_cell.get("proportion_spec", {})
		var preregistered_cell: Dictionary = official_records[ordinal]
		if (
			String(generated.get("campaign_role", "")) != "held_out_finite_decision"
			or String(receipt.get("campaign_id", "")) != ExactSpecScript.OFFICIAL_CAMPAIGN_ID
			or String(receipt.get("changed_axis", ""))
			!= String(expected_cell.get("changed_axis", ""))
			or String(receipt.get("direction", ""))
			!= String(expected_cell.get("direction", ""))
			or CanonicalJsonScript.sha256(spec) != CanonicalJsonScript.sha256(expected_spec)
			or CanonicalJsonScript.sha256(spec)
			!= CanonicalJsonScript.sha256(official_specs[ordinal])
			or String(preregistered_cell.get("morphology_id", ""))
			!= String(spec.get("morphology_id", ""))
			or String(preregistered_cell.get("generator_receipt_sha256", ""))
			!= String(generated.get("generator_receipt_sha256", ""))
			or String(preregistered_cell.get("proportion_spec_sha256", ""))
			!= String(generated.get("proportion_spec_sha256", ""))
			or not bool(
				ExactSpecScript.validate_exact_proportion_spec(generator_index, spec).get(
					"ok", false
				)
			)
		):
			return _failure(
				"QSDK_R05E_SOURCE_GATE_OFFICIAL_CELL_MISMATCH",
				{"generator_index": generator_index},
			)

		var changed_axes := _strict_changed_axes(spec, reference)
		var changed_axis := String(expected_cell.get("changed_axis", ""))
		var direction := String(expected_cell.get("direction", ""))
		var endpoints: Array = exact_endpoints.get(changed_axis, [])
		var endpoint_ordinal := 0 if direction == "low" else 1
		if (
			changed_axes.size() != 1
			or String(changed_axes[0]) != changed_axis
			or direction not in ["low", "high"]
			or endpoints.size() != 2
			or float(spec.get(changed_axis, NAN)) != float(endpoints[endpoint_ordinal])
		):
			return _failure(
				"QSDK_R05E_SOURCE_GATE_AXIS_STAR_SHAPE_MISMATCH",
				{"generator_index": generator_index},
			)
		var axis_directions: Dictionary = direction_counts[changed_axis]
		axis_directions[direction] = int(axis_directions[direction]) + 1
		direction_counts[changed_axis] = axis_directions
		var morphology_id := String(spec["morphology_id"])
		if official_ids.has(morphology_id):
			return _failure("QSDK_R05E_SOURCE_GATE_DUPLICATE_OFFICIAL_MORPHOLOGY_ID")
		official_ids[morphology_id] = true
		official_spec_digests[String(generated["proportion_spec_sha256"])] = true
		official_compiled_records.append(_cell_record(generator_index, generated))

		var altered_spec := spec.duplicate(true)
		altered_spec[changed_axis] = float(altered_spec[changed_axis]) + 0.000001
		altered_coordinate_controls.append(
			_negative_control(
				"altered_coordinate_%d" % generator_index,
				ExactSpecScript.validate_exact_proportion_spec(generator_index, altered_spec),
				["QSDK_R05E_DESCRIPTOR_NOT_EXACT"],
			)
		)

	for axis_value in ExactSpecScript.AXIS_KEYS:
		var axis := String(axis_value)
		var counts: Dictionary = direction_counts.get(axis, {})
		if int(counts.get("low", -1)) != 1 or int(counts.get("high", -1)) != 1:
			return _failure(
				"QSDK_R05E_SOURCE_GATE_AXIS_DIRECTION_COVERAGE_MISMATCH",
				{"axis": axis, "counts": counts},
			)

	var official_set_validation := ExactSpecScript.validate_exact_cell_set(
		official_compiled_records,
		ExactSpecScript.OFFICIAL_INDICES,
	)
	if not bool(official_set_validation.get("ok", false)) or not _zero_authority(official_set_validation):
		return _failure("QSDK_R05E_SOURCE_GATE_OFFICIAL_SET_VALIDATION_FAILED")

	var ghost_design: Dictionary = (
		design.get("prospective_sequence", {}).get("development_route_ghost", {})
	)
	var ghost_index := int(ghost_design.get("generator_index", -1))
	var ghost_generated := ExactSpecScript.compile_generation(ghost_index)
	var ghost_spec: Dictionary = ghost_generated.get("proportion_spec", {})
	var expected_ghost_spec: Dictionary = ghost_design.get("proportion_spec", {})
	var ghost_record: Dictionary = ghost_records[0]
	var ghost_compiled_records := [_cell_record(ghost_index, ghost_generated)]
	if (
		ghost_index != ExactSpecScript.DEVELOPMENT_GHOST_INDEX
		or not bool(ghost_generated.get("ok", false))
		or not _zero_authority(ghost_generated)
		or String(ghost_generated.get("campaign_role", "")) != "development_route_ghost"
		or String(ghost_generated.get("generator_receipt", {}).get("campaign_id", ""))
		!= ExactSpecScript.DEVELOPMENT_GHOST_CAMPAIGN_ID
		or CanonicalJsonScript.sha256(ghost_spec)
		!= CanonicalJsonScript.sha256(expected_ghost_spec)
		or CanonicalJsonScript.sha256(ghost_spec)
		!= CanonicalJsonScript.sha256(ghost_specs[0])
		or String(ghost_record.get("morphology_id", ""))
		!= String(ghost_spec.get("morphology_id", ""))
		or String(ghost_record.get("generator_receipt_sha256", ""))
		!= String(ghost_generated.get("generator_receipt_sha256", ""))
		or String(ghost_record.get("proportion_spec_sha256", ""))
		!= String(ghost_generated.get("proportion_spec_sha256", ""))
		or official_ids.has(String(ghost_spec.get("morphology_id", "")))
		or official_spec_digests.has(String(ghost_generated.get("proportion_spec_sha256", "")))
		or _strict_changed_axes(ghost_spec, reference) != ["torso_length_scale"]
	):
		return _failure("QSDK_R05E_SOURCE_GATE_DEVELOPMENT_GHOST_MISMATCH")
	var ghost_set_validation := ExactSpecScript.validate_exact_cell_set(
		ghost_compiled_records,
		[ExactSpecScript.DEVELOPMENT_GHOST_INDEX],
	)
	if not bool(ghost_set_validation.get("ok", false)) or not _zero_authority(ghost_set_validation):
		return _failure("QSDK_R05E_SOURCE_GATE_GHOST_SET_VALIDATION_FAILED")

	var negative_controls: Array = []
	negative_controls.append_array(altered_coordinate_controls)
	negative_controls.append(
		_negative_control(
			"generator_index_string",
			ExactSpecScript.compile_generation("217"),
			["INVALID_QSDK_R05E_GENERATOR_INDEX_TYPE"],
		)
	)
	negative_controls.append(
		_negative_control(
			"generator_index_float",
			ExactSpecScript.compile_generation(217.0),
			["INVALID_QSDK_R05E_GENERATOR_INDEX_TYPE"],
		)
	)
	for unknown_index in [216, 230]:
		negative_controls.append(
			_negative_control(
				"unknown_index_%d" % unknown_index,
				ExactSpecScript.compile_generation(unknown_index),
				["UNKNOWN_QSDK_R05E_GENERATOR_INDEX"],
			)
		)
	var generation_217 := ExactSpecScript.compile_generation(217)
	negative_controls.append(
		_negative_control(
			"generator_receipt_digest",
			ExactSpecScript.verify_generation(
				217,
				"sha256:" + "0".repeat(64),
				String(generation_217["proportion_spec_sha256"]),
			),
			["QSDK_R05E_GENERATION_DIGEST_MISMATCH"],
		)
	)
	negative_controls.append(
		_negative_control(
			"proportion_spec_digest",
			ExactSpecScript.verify_generation(
				217,
				String(generation_217["generator_receipt_sha256"]),
				"sha256:" + "0".repeat(64),
			),
			["QSDK_R05E_GENERATION_DIGEST_MISMATCH"],
		)
	)
	negative_controls.append(
		_negative_control(
			"descriptor_not_object",
			ExactSpecScript.validate_exact_proportion_spec(217, []),
			["QSDK_R05E_DESCRIPTOR_NOT_OBJECT"],
		)
	)
	for axis_value in ExactSpecScript.AXIS_KEYS:
		var axis := String(axis_value)
		var interval: Array = historical_intervals.get(axis, [])
		if interval.size() != 3:
			return _failure("QSDK_R05E_SOURCE_GATE_HISTORICAL_INTERVAL_MISSING")
		var out_of_domain_spec: Dictionary = generation_217["proportion_spec"].duplicate(true)
		out_of_domain_spec[axis] = float(interval[2]) + 0.1
		negative_controls.append(
			_negative_control(
				"out_of_domain_%s" % axis,
				ExactSpecScript.validate_exact_proportion_spec(217, out_of_domain_spec),
				["QSDK_R05E_DESCRIPTOR_NOT_EXACT"],
			)
		)

	var partial_records := [official_compiled_records[0]]
	negative_controls.append(
		_negative_control(
			"partial_expected_index_set",
			ExactSpecScript.validate_exact_cell_set(partial_records, [217]),
			["QSDK_R05E_EXPECTED_INDEX_SET_INVALID"],
		)
	)
	var duplicate_index_records: Array = official_compiled_records.duplicate(true)
	duplicate_index_records[1] = (duplicate_index_records[0] as Dictionary).duplicate(true)
	negative_controls.append(
		_negative_control(
			"duplicate_index",
			ExactSpecScript.validate_exact_cell_set(
				duplicate_index_records, ExactSpecScript.OFFICIAL_INDICES
			),
			["QSDK_R05E_CELL_INDEX_DUPLICATE_OR_OUT_OF_ORDER"],
		)
	)
	var duplicate_identity_records: Array = official_compiled_records.duplicate(true)
	var duplicate_identity: Dictionary = duplicate_identity_records[1]
	duplicate_identity["morphology_id"] = official_compiled_records[0]["morphology_id"]
	duplicate_identity_records[1] = duplicate_identity
	negative_controls.append(
		_negative_control(
			"duplicate_identity",
			ExactSpecScript.validate_exact_cell_set(
				duplicate_identity_records, ExactSpecScript.OFFICIAL_INDICES
			),
			["QSDK_R05E_MORPHOLOGY_ID_DUPLICATE_OR_MISMATCH"],
		)
	)
	var out_of_order_records: Array = official_compiled_records.duplicate(true)
	var first_record: Variant = out_of_order_records[0]
	out_of_order_records[0] = out_of_order_records[1]
	out_of_order_records[1] = first_record
	negative_controls.append(
		_negative_control(
			"out_of_order",
			ExactSpecScript.validate_exact_cell_set(
				out_of_order_records, ExactSpecScript.OFFICIAL_INDICES
			),
			["QSDK_R05E_CELL_INDEX_DUPLICATE_OR_OUT_OF_ORDER"],
		)
	)
	var digest_mutation_records: Array = official_compiled_records.duplicate(true)
	var digest_mutation: Dictionary = digest_mutation_records[0]
	digest_mutation["generator_receipt_sha256"] = "sha256:" + "0".repeat(64)
	digest_mutation_records[0] = digest_mutation
	negative_controls.append(
		_negative_control(
			"cell_digest",
			ExactSpecScript.validate_exact_cell_set(
				digest_mutation_records, ExactSpecScript.OFFICIAL_INDICES
			),
			["QSDK_R05E_CELL_DIGEST_MISMATCH"],
		)
	)
	var extra_field_records: Array = official_compiled_records.duplicate(true)
	var extra_field: Dictionary = extra_field_records[0]
	extra_field["unexpected"] = true
	extra_field_records[0] = extra_field
	negative_controls.append(
		_negative_control(
			"extra_cell_field",
			ExactSpecScript.validate_exact_cell_set(
				extra_field_records, ExactSpecScript.OFFICIAL_INDICES
			),
			["QSDK_R05E_CELL_SHAPE_INVALID"],
		)
	)
	var missing_field_records: Array = official_compiled_records.duplicate(true)
	var missing_field: Dictionary = missing_field_records[0]
	missing_field.erase("proportion_spec_sha256")
	missing_field_records[0] = missing_field
	negative_controls.append(
		_negative_control(
			"missing_cell_field",
			ExactSpecScript.validate_exact_cell_set(
				missing_field_records, ExactSpecScript.OFFICIAL_INDICES
			),
			["QSDK_R05E_CELL_SHAPE_INVALID"],
		)
	)

	for control_value in negative_controls:
		var control: Dictionary = control_value
		if not bool(control.get("passed", false)):
			return _failure("QSDK_R05E_SOURCE_GATE_NEGATIVE_CONTROL_FAILED", control)
	if root.get_child_count() != 0:
		return _failure("QSDK_R05E_SOURCE_GATE_CREATED_SCENE_CHILD")

	return {
		"schema_version": "sporespore_qsdk_r05e_exact_finite_morphology_source_zero_world_v1",
		"gate_id": "QSDK-R05E",
		"ledger_scope": {
			"subsystem": "walking",
			"engine_scope": "godot_jolt",
			"authority_mode": "zero_world_exact_finite_source_and_mutation_control",
			"question_class": "development",
		},
		"ok": true,
		"failure_code": "",
		"r05d_design_digest_exact": true,
		"preregistration_digests_exact": true,
		"official_descriptor_compile_count": official_compiled_records.size(),
		"development_ghost_descriptor_compile_count": ghost_compiled_records.size(),
		"official_exact_set_validation_passed": true,
		"development_ghost_exact_set_validation_passed": true,
		"one_axis_changed_per_official_descriptor": true,
		"every_axis_has_exactly_one_low_and_one_high_descriptor": true,
		"development_ghost_distinct_from_official_population": true,
		"negative_control_count": negative_controls.size(),
		"negative_controls_passed": negative_controls.size(),
		"unknown_index_and_type_refusal_count": 4,
		"altered_coordinate_refusal_count": altered_coordinate_controls.size(),
		"out_of_domain_refusal_count": ExactSpecScript.AXIS_KEYS.size(),
		"set_shape_identity_order_and_digest_refusal_count": 7,
		"held_out_locomotion_outcome_exposure_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": root.get_child_count(),
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _cell_record(generator_index: int, generated: Dictionary) -> Dictionary:
	var spec: Dictionary = generated.get("proportion_spec", {})
	return {
		"generator_index": generator_index,
		"morphology_id": String(spec.get("morphology_id", "")),
		"generator_receipt_sha256": String(generated.get("generator_receipt_sha256", "")),
		"proportion_spec_sha256": String(generated.get("proportion_spec_sha256", "")),
	}


static func _strict_changed_axes(spec: Dictionary, reference: Dictionary) -> Array:
	var changed: Array = []
	for axis_value in ExactSpecScript.AXIS_KEYS:
		var axis := String(axis_value)
		if float(spec.get(axis, NAN)) != float(reference.get(axis, NAN)):
			changed.append(axis)
	return changed


static func _negative_control(
	control_id: String,
	result: Dictionary,
	expected_failure_codes: Array,
) -> Dictionary:
	var failure_code := String(result.get("failure_code", ""))
	return {
		"control_id": control_id,
		"passed": (
			not bool(result.get("ok", true))
			and expected_failure_codes.has(failure_code)
			and _zero_authority(result)
		),
		"observed_failure_code": failure_code,
		"expected_failure_codes": expected_failure_codes.duplicate(),
	}


static func _zero_authority(result: Dictionary) -> bool:
	return (
		int(result.get("world_attempt_count", -1)) == 0
		and int(result.get("world_build_count", -1)) == 0
		and int(result.get("solver_step_count", -1)) == 0
		and not bool(result.get("physical_acceptance_authority", true))
	)


static func _read_json_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r05e_exact_finite_morphology_source_zero_world_v1",
		"gate_id": "QSDK-R05E",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"held_out_locomotion_outcome_exposure_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
