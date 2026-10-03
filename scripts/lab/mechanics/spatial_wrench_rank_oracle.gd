class_name LabSpatialWrenchRankOracle
extends RefCounted
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## Pure BR14A prephysical spatial-wrench rank oracle.
##
## The oracle nondimensionalizes moment rows by one declared characteristic
## length and computes linear span with modified Gram-Schmidt. This is a
## structural upper bound only: it does not solve unilateral/friction
## feasibility, prove actuator reachability or capacity, execute dynamics,
## select a canonical morphology, or establish any physical capability.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA_VERSION := "spatial_wrench_rank_request_v1"
const REPORT_SCHEMA_VERSION := "spatial_wrench_rank_report_v1"
const POSITIVE_CLAIM := "prephysical_linearized_spatial_wrench_rank_only"
const CLAIM_BOUNDARY := (
	"BR14A prephysical linearized spatial-wrench rank only. Moment rows are "
	+ "nondimensionalized by the declared characteristic length. Rank is an "
	+ "upper bound and establishes no unilateral or friction-cone feasibility, "
	+ "actuator reachability or capacity, dynamic controllability, scaffold "
	+ "removal, canonical morphology selection, physical stance, bracing, "
	+ "catch, fall arrest, get-up, step, gait, walking, repair, or guidance."
)
const AXES: Array[String] = [
	"force_x",
	"force_y",
	"force_z",
	"moment_x",
	"moment_y",
	"moment_z",
]
const SOURCE_KINDS: Array[String] = [
	"ordinary_contact_linearization",
	"actuator_analytic",
	"scaffold",
]
const REQUEST_FIELDS: Array[String] = [
	"schema_version",
	"analysis_id",
	"reference_frame",
	"characteristic_length_m",
	"rank_tolerance",
	"axis_residual_tolerance",
	"columns",
	"required_axes",
	"intentionally_omitted_axes",
	"claim_boundary",
	"automatic_creature_guidance_allowed",
]
const COLUMN_FIELDS: Array[String] = [
	"column_id",
	"source_kind",
	"source_id",
	"wrench_per_unit",
]


static func compile(configuration: Dictionary) -> Dictionary:
	var field_result := _exact_fields(configuration, REQUEST_FIELDS, "request")
	if not bool(field_result.get("ok", false)):
		return field_result
	if String(configuration["schema_version"]) != SCHEMA_VERSION:
		return _failure("SPATIAL_RANK_SCHEMA_INVALID", "Request schema is not recognized.")
	if (
		not _stable_id(String(configuration["analysis_id"]))
		or String(configuration["reference_frame"]) != "centroidal_world"
	):
		return _failure(
			"SPATIAL_RANK_IDENTITY_INVALID",
			"Analysis ID and centroidal-world reference frame are required."
		)
	if (
		not _finite_number(configuration["characteristic_length_m"])
		or float(configuration["characteristic_length_m"]) <= 0.0
		or not _finite_number(configuration["rank_tolerance"])
		or float(configuration["rank_tolerance"]) <= 0.0
		or float(configuration["rank_tolerance"]) > 1.0e-3
		or not _finite_number(configuration["axis_residual_tolerance"])
		or float(configuration["axis_residual_tolerance"]) <= 0.0
		or float(configuration["axis_residual_tolerance"]) > 1.0e-3
	):
		return _failure(
			"SPATIAL_RANK_TOLERANCE_INVALID",
			"Characteristic length and bounded positive tolerances are required."
		)
	if (
		String(configuration["claim_boundary"]) != CLAIM_BOUNDARY
		or typeof(configuration["automatic_creature_guidance_allowed"]) != TYPE_BOOL
		or bool(configuration["automatic_creature_guidance_allowed"])
	):
		return _failure(
			"SPATIAL_RANK_CLAIM_BOUNDARY_INVALID",
			"The exact non-capability claim and false guidance authority are required."
		)
	var axes_result := _validate_axis_partition(
		configuration["required_axes"], configuration["intentionally_omitted_axes"]
	)
	if not bool(axes_result.get("ok", false)):
		return axes_result
	if typeof(configuration["columns"]) != TYPE_ARRAY:
		return _failure("SPATIAL_RANK_COLUMNS_INVALID", "Columns must be one array.")
	var columns: Array = configuration["columns"]
	if columns.is_empty() or columns.size() > 64:
		return _failure(
			"SPATIAL_RANK_COLUMNS_INVALID",
			"Between one and sixty-four declared columns are required."
		)
	var seen_columns: Dictionary = {}
	for column_value in columns:
		if typeof(column_value) != TYPE_DICTIONARY:
			return _failure("SPATIAL_RANK_COLUMN_INVALID", "Every column must be one object.")
		var column: Dictionary = column_value
		var column_fields := _exact_fields(column, COLUMN_FIELDS, "column")
		if not bool(column_fields.get("ok", false)):
			return column_fields
		var column_id := String(column["column_id"])
		if (
			not _stable_id(column_id)
			or seen_columns.has(column_id)
			or not _stable_id(String(column["source_id"]))
			or String(column["source_kind"]) not in SOURCE_KINDS
		):
			return _failure(
				"SPATIAL_RANK_COLUMN_IDENTITY_INVALID",
				"Column and source identities must be unique, stable, and registered."
			)
		seen_columns[column_id] = true
		var vector_result := _vector6(column["wrench_per_unit"])
		if not bool(vector_result.get("ok", false)):
			return vector_result
		if _norm(vector_result["value"]) <= float(configuration["rank_tolerance"]):
			return _failure(
				"SPATIAL_RANK_ZERO_COLUMN",
				"A zero or near-zero column cannot enter the rank oracle."
			)
	var sealed := configuration.duplicate(true)
	sealed["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	return {"ok": true, "request": FrozenValueScript.snapshot(sealed)}


static func analyze(compiled_value: Variant) -> Dictionary:
	if typeof(compiled_value) != TYPE_DICTIONARY:
		return _failure("SPATIAL_RANK_REQUEST_INVALID", "Compiled request must be one object.")
	var compiled: Dictionary = compiled_value
	if not compiled.has("configuration_sha256"):
		return _failure("SPATIAL_RANK_DIGEST_MISSING", "Compiled request digest is missing.")
	var raw := compiled.duplicate(true)
	var recorded_digest := String(raw["configuration_sha256"])
	raw.erase("configuration_sha256")
	var recompiled := compile(raw)
	if (
		not bool(recompiled.get("ok", false))
		or String((recompiled["request"] as Dictionary)["configuration_sha256"]) != recorded_digest
	):
		return _failure(
			"SPATIAL_RANK_DIGEST_MISMATCH",
			"Compiled request differs from its sealed configuration."
		)
	var characteristic_length := float(compiled["characteristic_length_m"])
	var rank_tolerance := float(compiled["rank_tolerance"])
	var all_columns: Array = []
	var non_scaffold_columns: Array = []
	var contact_columns: Array = []
	var actuator_columns: Array = []
	var scaffold_columns: Array = []
	for column_value in compiled["columns"]:
		var column: Dictionary = column_value
		var nondimensionalized := _nondimensionalized(
			column["wrench_per_unit"], characteristic_length
		)
		all_columns.append(nondimensionalized)
		match String(column["source_kind"]):
			"ordinary_contact_linearization":
				contact_columns.append(nondimensionalized)
				non_scaffold_columns.append(nondimensionalized)
			"actuator_analytic":
				actuator_columns.append(nondimensionalized)
				non_scaffold_columns.append(nondimensionalized)
			"scaffold":
				scaffold_columns.append(nondimensionalized)
	var all_basis := _orthonormal_basis(all_columns, rank_tolerance)
	var non_scaffold_basis := _orthonormal_basis(non_scaffold_columns, rank_tolerance)
	var contact_basis := _orthonormal_basis(contact_columns, rank_tolerance)
	var actuator_basis := _orthonormal_basis(actuator_columns, rank_tolerance)
	var scaffold_basis := _orthonormal_basis(scaffold_columns, rank_tolerance)
	var required: Array = compiled["required_axes"]
	var omitted: Array = compiled["intentionally_omitted_axes"]
	var residual_tolerance := float(compiled["axis_residual_tolerance"])
	var axis_results: Array = []
	var all_required_without_scaffold := true
	var any_scaffold_dependency := false
	for axis_index in range(AXES.size()):
		var axis := AXES[axis_index]
		var target := _unit_axis(axis_index)
		var without_residual := _projection_residual(target, non_scaffold_basis)
		var with_residual := _projection_residual(target, all_basis)
		var without_supported := without_residual <= residual_tolerance
		var with_supported := with_residual <= residual_tolerance
		var is_required := required.has(axis)
		var scaffold_dependent := is_required and not without_supported and with_supported
		if is_required and not without_supported:
			all_required_without_scaffold = false
		if scaffold_dependent:
			any_scaffold_dependency = true
		(
			axis_results
			. append(
				{
					"axis": axis,
					"required": is_required,
					"intentionally_omitted": omitted.has(axis),
					"residual_without_scaffold": without_residual,
					"residual_with_scaffold": with_residual,
					"structurally_spanned_without_scaffold": without_supported,
					"structurally_spanned_with_scaffold": with_supported,
					"scaffold_dependent": scaffold_dependent,
				}
			)
		)
	var report := {
		"schema_version": REPORT_SCHEMA_VERSION,
		"analysis_id": compiled["analysis_id"],
		"configuration_sha256": recorded_digest,
		"reference_frame": "centroidal_world",
		"characteristic_length_m": characteristic_length,
		"column_count": all_columns.size(),
		"ordinary_contact_column_count": contact_columns.size(),
		"actuator_column_count": actuator_columns.size(),
		"scaffold_column_count": scaffold_columns.size(),
		"all_linearized_rank": all_basis.size(),
		"non_scaffold_linearized_rank": non_scaffold_basis.size(),
		"ordinary_contact_linearized_rank": contact_basis.size(),
		"actuator_analytic_rank": actuator_basis.size(),
		"scaffold_rank": scaffold_basis.size(),
		"required_axes": required.duplicate(),
		"intentionally_omitted_axes": omitted.duplicate(),
		"axis_results": axis_results,
		"all_required_axes_structurally_spanned_without_scaffold": all_required_without_scaffold,
		"any_required_axis_scaffold_dependent": any_scaffold_dependency,
		"positive_claim": POSITIVE_CLAIM,
		"claim_boundary": CLAIM_BOUNDARY,
		"rank_is_nondimensionalized_linear_upper_bound": true,
		"unilateral_or_friction_feasibility_established": false,
		"actuator_reachability_or_capacity_established": false,
		"dynamic_controllability_established": false,
		"canonical_morphology_selected": false,
		"physical_stance_or_recovery_established": false,
		"step_gait_or_walking_established": false,
		"automatic_creature_guidance_allowed": false,
	}
	report["report_sha256"] = CanonicalJsonScript.sha256(report)
	return {"ok": true, "report": FrozenValueScript.snapshot(report)}


static func contact_force_column(
	column_id: String,
	contact_id: String,
	contact_point_world_m: Vector3,
	center_of_mass_world_m: Vector3,
	force_direction_world: Vector3,
) -> Dictionary:
	if (
		not _stable_id(column_id)
		or not _stable_id(contact_id)
		or not contact_point_world_m.is_finite()
		or not center_of_mass_world_m.is_finite()
		or not force_direction_world.is_finite()
		or absf(force_direction_world.length() - 1.0) > 1.0e-6
	):
		return _failure(
			"SPATIAL_RANK_CONTACT_COLUMN_INVALID",
			"Contact column requires stable IDs, finite geometry, and a unit force direction."
		)
	var arm := contact_point_world_m - center_of_mass_world_m
	var moment := arm.cross(force_direction_world)
	return {
		"ok": true,
		"column":
		{
			"column_id": column_id,
			"source_kind": "ordinary_contact_linearization",
			"source_id": contact_id,
			"wrench_per_unit":
			[
				force_direction_world.x,
				force_direction_world.y,
				force_direction_world.z,
				moment.x,
				moment.y,
				moment.z,
			],
		},
	}


static func _validate_axis_partition(required_value: Variant, omitted_value: Variant) -> Dictionary:
	if typeof(required_value) != TYPE_ARRAY or typeof(omitted_value) != TYPE_ARRAY:
		return _failure(
			"SPATIAL_RANK_AXIS_PARTITION_INVALID",
			"Required and intentionally omitted axes must be arrays."
		)
	var required: Array = required_value
	var omitted: Array = omitted_value
	if required.is_empty():
		return _failure(
			"SPATIAL_RANK_AXIS_PARTITION_INVALID", "At least one task axis must be required."
		)
	var seen: Dictionary = {}
	for value in required + omitted:
		var axis := String(value)
		if axis not in AXES or seen.has(axis):
			return _failure(
				"SPATIAL_RANK_AXIS_PARTITION_INVALID", "Axes must be unique registered names."
			)
		seen[axis] = true
	if seen.size() != AXES.size():
		return _failure(
			"SPATIAL_RANK_AXIS_PARTITION_INVALID",
			"Every spatial wrench axis must be required or intentionally omitted."
		)
	return {"ok": true}


static func _orthonormal_basis(columns: Array, tolerance: float) -> Array:
	var basis: Array = []
	for column_value in columns:
		var candidate: Array = (column_value as Array).duplicate()
		var original_norm := _norm(candidate)
		if original_norm <= tolerance:
			continue
		for _pass in range(2):
			for basis_value in basis:
				var direction: Array = basis_value
				var coefficient := _dot(candidate, direction)
				for index in range(6):
					candidate[index] = (
						float(candidate[index]) - coefficient * float(direction[index])
					)
		var residual_norm := _norm(candidate)
		if residual_norm <= tolerance * maxf(1.0, original_norm):
			continue
		for index in range(6):
			candidate[index] = float(candidate[index]) / residual_norm
		basis.append(candidate)
	return basis


static func _projection_residual(target: Array, basis: Array) -> float:
	var residual: Array = target.duplicate()
	for direction_value in basis:
		var direction: Array = direction_value
		var coefficient := _dot(residual, direction)
		for index in range(6):
			residual[index] = float(residual[index]) - coefficient * float(direction[index])
	return _norm(residual)


static func _nondimensionalized(wrench_value: Variant, characteristic_length: float) -> Array:
	var wrench: Array = wrench_value
	return [
		float(wrench[0]),
		float(wrench[1]),
		float(wrench[2]),
		float(wrench[3]) / characteristic_length,
		float(wrench[4]) / characteristic_length,
		float(wrench[5]) / characteristic_length,
	]


static func _unit_axis(index: int) -> Array:
	var value := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	value[index] = 1.0
	return value


static func _vector6(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != 6:
		return _failure(
			"SPATIAL_RANK_COLUMN_VECTOR_INVALID",
			"Every wrench column must contain six numeric values."
		)
	var vector: Array = []
	for component in value:
		if not _finite_number(component):
			return _failure(
				"SPATIAL_RANK_COLUMN_VECTOR_INVALID",
				"Every wrench component must be finite and numeric."
			)
		vector.append(float(component))
	return {"ok": true, "value": vector}


static func _dot(left: Array, right: Array) -> float:
	var result := 0.0
	for index in range(6):
		result += float(left[index]) * float(right[index])
	return result


static func _norm(value: Array) -> float:
	return sqrt(_dot(value, value))


static func _exact_fields(value: Dictionary, expected: Array[String], label: String) -> Dictionary:
	if value.size() != expected.size():
		return _failure(
			"SPATIAL_RANK_FIELDS_INVALID", "%s field set is not exact." % label.capitalize()
		)
	for field in expected:
		if not value.has(field):
			return _failure(
				"SPATIAL_RANK_FIELDS_INVALID",
				"%s is missing field %s." % [label.capitalize(), field]
			)
	return {"ok": true}


static func _stable_id(value: String) -> bool:
	if value.is_empty() or value.length() > 160:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		var allowed := (
			(code >= 65 and code <= 90)
			or (code >= 97 and code <= 122)
			or (code >= 48 and code <= 57)
			or code in [46, 95, 45]
		)
		if not allowed or (index == 0 and code >= 48 and code <= 57):
			return false
	return true


static func _finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


static func _failure(code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"message": message,
	}
