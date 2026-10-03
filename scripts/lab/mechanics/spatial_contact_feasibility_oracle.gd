class_name LabSpatialContactFeasibilityOracle
extends RefCounted
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## Pure BR14A prephysical bounded contact-wrench feasibility oracle.
##
## Each ordinary contact is approximated by an inscribed four-ray friction
## pyramid: n +/- mu*u and n +/- mu*v. Nonnegative ray coefficients make
## pulling impossible; their per-contact sum is capped by declared normal
## capacity. Projected gradient solves only this convex command-allocation
## screen. Results are commands, never measured per-contact loads.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA_VERSION := "spatial_contact_feasibility_request_v1"
const REPORT_SCHEMA_VERSION := "spatial_contact_feasibility_report_v1"
const POSITIVE_CLAIM := "prephysical_polyhedral_contact_wrench_feasibility_only"
const CLAIM_BOUNDARY := (
	"BR14A prephysical conservative polyhedral ordinary-contact wrench "
	+ "feasibility only. The result is a bounded nonnegative command "
	+ "allocation inside an inscribed four-ray friction pyramid. It is not a "
	+ "measurement and establishes no exact Coulomb-cone completeness, "
	+ "actuator reachability or capacity, collision-free pose, dynamic "
	+ "controllability, scaffold removal, canonical morphology selection, "
	+ "physical stance, bracing, catch, fall arrest, get-up, step, gait, "
	+ "walking, repair, automatic application, or creature guidance."
)
const REQUEST_FIELDS: Array[String] = [
	"schema_version",
	"analysis_id",
	"reference_frame",
	"center_of_mass_world_m",
	"characteristic_length_m",
	"desired_wrench_world",
	"contacts",
	"residual_tolerance",
	"maximum_iterations",
	"claim_boundary",
	"automatic_creature_guidance_allowed",
]
const CONTACT_FIELDS: Array[String] = [
	"contact_id",
	"point_world_m",
	"normal_world",
	"tangent_u_world",
	"tangent_v_world",
	"friction_coefficient",
	"normal_capacity_n",
	"ordinary_unilateral_contact",
]
const FRAME_TOLERANCE := 1.0e-6


static func compile(configuration: Dictionary) -> Dictionary:
	var fields := _exact_fields(configuration, REQUEST_FIELDS, "request")
	if not bool(fields.get("ok", false)):
		return fields
	if String(configuration["schema_version"]) != SCHEMA_VERSION:
		return _failure("SPATIAL_CONTACT_SCHEMA_INVALID", "Request schema is not recognized.")
	if (
		not _stable_id(String(configuration["analysis_id"]))
		or String(configuration["reference_frame"]) != "centroidal_world"
	):
		return _failure(
			"SPATIAL_CONTACT_IDENTITY_INVALID",
			"Stable analysis identity and centroidal-world frame are required."
		)
	if (
		not _finite_number(configuration["characteristic_length_m"])
		or float(configuration["characteristic_length_m"]) <= 0.0
		or not _finite_number(configuration["residual_tolerance"])
		or float(configuration["residual_tolerance"]) <= 0.0
		or float(configuration["residual_tolerance"]) > 1.0
		or typeof(configuration["maximum_iterations"]) != TYPE_INT
		or int(configuration["maximum_iterations"]) < 10
		or int(configuration["maximum_iterations"]) > 20000
	):
		return _failure(
			"SPATIAL_CONTACT_NUMERIC_POLICY_INVALID",
			"Positive characteristic length, bounded residual tolerance, and iteration policy are required."
		)
	var desired := _vector6(configuration["desired_wrench_world"])
	if not bool(desired.get("ok", false)):
		return desired
	var center_of_mass := _strict_vector3(configuration["center_of_mass_world_m"])
	if not bool(center_of_mass.get("ok", false)):
		return center_of_mass
	if (
		String(configuration["claim_boundary"]) != CLAIM_BOUNDARY
		or typeof(configuration["automatic_creature_guidance_allowed"]) != TYPE_BOOL
		or bool(configuration["automatic_creature_guidance_allowed"])
	):
		return _failure(
			"SPATIAL_CONTACT_CLAIM_BOUNDARY_INVALID",
			"The exact non-capability boundary and false guidance authority are required."
		)
	if typeof(configuration["contacts"]) != TYPE_ARRAY:
		return _failure("SPATIAL_CONTACT_SET_INVALID", "Contacts must be one array.")
	var contacts: Array = configuration["contacts"]
	if contacts.is_empty() or contacts.size() > 16:
		return _failure(
			"SPATIAL_CONTACT_SET_INVALID", "Between one and sixteen contacts are required."
		)
	var seen: Dictionary = {}
	for contact_value in contacts:
		var result := _validate_contact(contact_value)
		if not bool(result.get("ok", false)):
			return result
		var contact: Dictionary = contact_value
		var contact_id := String(contact["contact_id"])
		if seen.has(contact_id):
			return _failure("SPATIAL_CONTACT_ID_DUPLICATE", "Contact identities must be unique.")
		seen[contact_id] = true
	var sealed := configuration.duplicate(true)
	sealed["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	return {"ok": true, "request": FrozenValueScript.snapshot(sealed)}


static func analyze(compiled_value: Variant) -> Dictionary:
	if typeof(compiled_value) != TYPE_DICTIONARY:
		return _failure("SPATIAL_CONTACT_REQUEST_INVALID", "Compiled request must be one object.")
	var compiled: Dictionary = compiled_value
	if not compiled.has("configuration_sha256"):
		return _failure("SPATIAL_CONTACT_DIGEST_MISSING", "Compiled request digest is missing.")
	var raw := compiled.duplicate(true)
	var digest := String(raw["configuration_sha256"])
	raw.erase("configuration_sha256")
	var recompiled := compile(raw)
	if (
		not bool(recompiled.get("ok", false))
		or String((recompiled["request"] as Dictionary)["configuration_sha256"]) != digest
	):
		return _failure(
			"SPATIAL_CONTACT_DIGEST_MISMATCH",
			"Compiled request differs from its sealed configuration."
		)
	var characteristic_length := float(compiled["characteristic_length_m"])
	var columns: Array = []
	var groups: Array = []
	for contact_value in compiled["contacts"]:
		var contact: Dictionary = contact_value
		var group_indices: Array = []
		var normal := _vector3(contact["normal_world"])
		var tangent_u := _vector3(contact["tangent_u_world"])
		var tangent_v := _vector3(contact["tangent_v_world"])
		var mu := float(contact["friction_coefficient"])
		for direction in [
			normal + mu * tangent_u,
			normal - mu * tangent_u,
			normal + mu * tangent_v,
			normal - mu * tangent_v,
		]:
			var index := columns.size()
			group_indices.append(index)
			columns.append(
				_contact_column(
					_vector3(contact["point_world_m"]),
					_vector3(compiled["center_of_mass_world_m"]),
					direction,
					characteristic_length
				)
			)
		(
			groups
			. append(
				{
					"contact_id": contact["contact_id"],
					"indices": group_indices,
					"capacity": float(contact["normal_capacity_n"]),
					"normal": normal,
					"tangent_u": tangent_u,
					"tangent_v": tangent_v,
					"friction_coefficient": mu,
				}
			)
		)
	var desired := _nondimensionalized(compiled["desired_wrench_world"], characteristic_length)
	var solution := _solve_projected(
		columns,
		groups,
		desired,
		float(compiled["residual_tolerance"]),
		int(compiled["maximum_iterations"])
	)
	var coefficients: Array = solution["coefficients"]
	var contact_commands: Array = []
	for group_value in groups:
		var group: Dictionary = group_value
		var force := Vector3.ZERO
		var normal_command := 0.0
		for local_index in range(4):
			var coefficient := float(coefficients[int(group["indices"][local_index])])
			normal_command += coefficient
			match local_index:
				0:
					force += (
						coefficient
						* (
							group["normal"]
							+ float(group["friction_coefficient"]) * group["tangent_u"]
						)
					)
				1:
					force += (
						coefficient
						* (
							group["normal"]
							- float(group["friction_coefficient"]) * group["tangent_u"]
						)
					)
				2:
					force += (
						coefficient
						* (
							group["normal"]
							+ float(group["friction_coefficient"]) * group["tangent_v"]
						)
					)
				3:
					force += (
						coefficient
						* (
							group["normal"]
							- float(group["friction_coefficient"]) * group["tangent_v"]
						)
					)
		var normal_force: float = force.dot(group["normal"] as Vector3)
		var tangent_force: Vector3 = force - normal_force * (group["normal"] as Vector3)
		var friction_limit: float = float(group["friction_coefficient"]) * normal_force
		(
			contact_commands
			. append(
				{
					"contact_id": group["contact_id"],
					"force_command_world_n": [force.x, force.y, force.z],
					"normal_command_n": normal_command,
					"normal_capacity_n": group["capacity"],
					"capacity_utilization": normal_command / float(group["capacity"]),
					"tangent_command_magnitude_n": tangent_force.length(),
					"friction_limit_n": friction_limit,
					"friction_utilization":
					tangent_force.length() / friction_limit if friction_limit > 0.0 else 0.0,
					"command_not_measurement": true,
				}
			)
		)
	var achieved := _multiply(columns, coefficients)
	var report := {
		"schema_version": REPORT_SCHEMA_VERSION,
		"analysis_id": compiled["analysis_id"],
		"configuration_sha256": digest,
		"reference_frame": "centroidal_world",
		"characteristic_length_m": characteristic_length,
		"contact_count": groups.size(),
		"friction_ray_count": columns.size(),
		"desired_wrench_world": compiled["desired_wrench_world"],
		"achieved_nondimensionalized_wrench": achieved,
		"residual_norm": solution["residual_norm"],
		"residual_tolerance": compiled["residual_tolerance"],
		"iterations_executed": solution["iterations_executed"],
		"feasible": solution["feasible"],
		"contact_commands": contact_commands,
		"positive_claim": POSITIVE_CLAIM,
		"claim_boundary": CLAIM_BOUNDARY,
		"inscribed_four_ray_friction_pyramid": true,
		"ordinary_unilateral_contact_only": true,
		"per_contact_values_are_commands_not_measurements": true,
		"exact_coulomb_cone_completeness_established": false,
		"actuator_reachability_or_capacity_established": false,
		"collision_free_pose_established": false,
		"dynamic_controllability_established": false,
		"canonical_morphology_selected": false,
		"physical_stance_or_recovery_established": false,
		"step_gait_or_walking_established": false,
		"automatic_creature_guidance_allowed": false,
	}
	report["report_sha256"] = CanonicalJsonScript.sha256(report)
	return {"ok": true, "report": FrozenValueScript.snapshot(report)}


static func _solve_projected(
	columns: Array, groups: Array, desired: Array, tolerance: float, maximum_iterations: int
) -> Dictionary:
	var coefficients: Array = []
	coefficients.resize(columns.size())
	coefficients.fill(0.0)
	var frobenius_squared := 0.0
	for column_value in columns:
		frobenius_squared += _dot(column_value, column_value)
	var step := 1.0 / maxf(frobenius_squared, 1.0e-12)
	var best := coefficients.duplicate()
	var best_residual := _norm(desired)
	var executed := 0
	for iteration in range(maximum_iterations):
		var achieved := _multiply(columns, coefficients)
		var residual := _subtract(achieved, desired)
		var residual_norm := _norm(residual)
		if residual_norm < best_residual:
			best_residual = residual_norm
			best = coefficients.duplicate()
		if residual_norm <= tolerance:
			executed = iteration + 1
			break
		var candidate := coefficients.duplicate()
		for index in range(columns.size()):
			candidate[index] = maxf(
				0.0, float(coefficients[index]) - step * _dot(columns[index], residual)
			)
		for group_value in groups:
			var group: Dictionary = group_value
			_project_group_simplex(candidate, group["indices"], float(group["capacity"]))
		coefficients = candidate
		executed = iteration + 1
	return {
		"coefficients": best,
		"residual_norm": best_residual,
		"iterations_executed": executed,
		"feasible": best_residual <= tolerance,
	}


static func _project_group_simplex(values: Array, indices: Array, capacity: float) -> void:
	var sum := 0.0
	for index_value in indices:
		var index := int(index_value)
		values[index] = maxf(0.0, float(values[index]))
		sum += float(values[index])
	if sum <= capacity:
		return
	var sorted: Array[float] = []
	for index_value in indices:
		sorted.append(float(values[int(index_value)]))
	sorted.sort()
	sorted.reverse()
	var cumulative := 0.0
	var rho := 0
	for index in range(sorted.size()):
		cumulative += sorted[index]
		var theta := (cumulative - capacity) / float(index + 1)
		if sorted[index] - theta > 0.0:
			rho = index + 1
	cumulative = 0.0
	for index in range(rho):
		cumulative += sorted[index]
	var threshold := (cumulative - capacity) / float(rho)
	for index_value in indices:
		var index := int(index_value)
		values[index] = maxf(0.0, float(values[index]) - threshold)


static func _validate_contact(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("SPATIAL_CONTACT_INVALID", "Every contact must be one object.")
	var contact: Dictionary = value
	var fields := _exact_fields(contact, CONTACT_FIELDS, "contact")
	if not bool(fields.get("ok", false)):
		return fields
	if not _stable_id(String(contact["contact_id"])):
		return _failure("SPATIAL_CONTACT_ID_INVALID", "Contact ID must be stable.")
	for field in [
		"point_world_m",
		"normal_world",
		"tangent_u_world",
		"tangent_v_world",
	]:
		var vector := _strict_vector3(contact[field])
		if not bool(vector.get("ok", false)):
			return vector
	var normal := _vector3(contact["normal_world"])
	var tangent_u := _vector3(contact["tangent_u_world"])
	var tangent_v := _vector3(contact["tangent_v_world"])
	if (
		absf(normal.length() - 1.0) > FRAME_TOLERANCE
		or absf(tangent_u.length() - 1.0) > FRAME_TOLERANCE
		or absf(tangent_v.length() - 1.0) > FRAME_TOLERANCE
		or absf(normal.dot(tangent_u)) > FRAME_TOLERANCE
		or absf(normal.dot(tangent_v)) > FRAME_TOLERANCE
		or absf(tangent_u.dot(tangent_v)) > FRAME_TOLERANCE
		or tangent_u.cross(tangent_v).dot(normal) < 1.0 - FRAME_TOLERANCE
	):
		return _failure(
			"SPATIAL_CONTACT_FRAME_INVALID",
			"Contact normal and tangents must form one right-handed orthonormal frame."
		)
	if (
		not _finite_number(contact["friction_coefficient"])
		or float(contact["friction_coefficient"]) < 0.0
		or float(contact["friction_coefficient"]) > 2.0
		or not _finite_number(contact["normal_capacity_n"])
		or float(contact["normal_capacity_n"]) <= 0.0
		or typeof(contact["ordinary_unilateral_contact"]) != TYPE_BOOL
		or not bool(contact["ordinary_unilateral_contact"])
	):
		return _failure(
			"SPATIAL_CONTACT_POLICY_INVALID",
			"Bounded friction, positive normal capacity, and ordinary unilateral contact are required."
		)
	return {"ok": true}


static func _contact_column(
	point: Vector3, center_of_mass: Vector3, force: Vector3, characteristic_length: float
) -> Array:
	var moment := (point - center_of_mass).cross(force)
	return [
		force.x,
		force.y,
		force.z,
		moment.x / characteristic_length,
		moment.y / characteristic_length,
		moment.z / characteristic_length,
	]


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


static func _multiply(columns: Array, coefficients: Array) -> Array:
	var result := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for column_index in range(columns.size()):
		var coefficient := float(coefficients[column_index])
		var column: Array = columns[column_index]
		for row in range(6):
			result[row] = float(result[row]) + coefficient * float(column[row])
	return result


static func _subtract(left: Array, right: Array) -> Array:
	var result: Array = []
	for index in range(6):
		result.append(float(left[index]) - float(right[index]))
	return result


static func _dot(left: Array, right: Array) -> float:
	var result := 0.0
	for index in range(6):
		result += float(left[index]) * float(right[index])
	return result


static func _norm(value: Array) -> float:
	return sqrt(_dot(value, value))


static func _vector6(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != 6:
		return _failure("SPATIAL_CONTACT_WRENCH_INVALID", "Desired wrench must contain six values.")
	for component in value:
		if not _finite_number(component):
			return _failure(
				"SPATIAL_CONTACT_WRENCH_INVALID", "Desired wrench must be finite and numeric."
			)
	return {"ok": true}


static func _strict_vector3(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != 3:
		return _failure(
			"SPATIAL_CONTACT_VECTOR_INVALID", "Contact vectors must contain three values."
		)
	for component in value:
		if not _finite_number(component):
			return _failure(
				"SPATIAL_CONTACT_VECTOR_INVALID", "Contact vectors must be finite and numeric."
			)
	return {"ok": true}


static func _vector3(value: Variant) -> Vector3:
	var array: Array = value
	return Vector3(float(array[0]), float(array[1]), float(array[2]))


static func _exact_fields(value: Dictionary, expected: Array[String], label: String) -> Dictionary:
	if value.size() != expected.size():
		return _failure(
			"SPATIAL_CONTACT_FIELDS_INVALID", "%s field set is not exact." % label.capitalize()
		)
	for field in expected:
		if not value.has(field):
			return _failure(
				"SPATIAL_CONTACT_FIELDS_INVALID",
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
