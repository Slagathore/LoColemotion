class_name LabSpatialCentroidalSupportController
extends RefCounted
# gdlint: disable=max-line-length

## Pure bounded centroidal-support command allocator.
##
## The controller turns measured whole-system state into a desired external
## body wrench, then allocates that command across three or more declared
## ordinary support contacts. Horizontal force is shared equally. Normal
## forces use the minimum-norm solution that satisfies total vertical force
## plus roll/pitch moment balance about the measured COM. When a contact
## declares a nonnegative preferred normal command, the minimum-norm objective
## is applied to the correction around that preference. This permits a smooth
## four-to-three commanded-load transition without treating the preference as
## a load measurement.
##
## Per-contact values are commands, never measurements. The returned
## `joint_task_force_delta_world_n` is the opposing endpoint-force increment
## intended for a receipt-backed J-transpose actuator map; it is not applied
## here.

const REQUEST_SCHEMA_VERSION := "spatial_centroidal_support_request_v1"
const _EPSILON := 1.0e-10


static func command(request: Dictionary) -> Dictionary:
	var validation := _validate(request)
	if not bool(validation.get("ok", false)):
		return validation
	var support_contacts: Array = request["support_contacts"]
	var count := support_contacts.size()
	var mass_kg := float(request["whole_system_mass_kg"])
	var gravity_m_s2 := float(request["gravity_m_s2"])
	var center_of_mass := _vector3(request["center_of_mass_world_m"])
	var center_of_mass_velocity := _vector3(request["center_of_mass_velocity_world_m_s"])
	var target_center_of_mass := _vector3(request["target_center_of_mass_world_m"])

	var desired_horizontal_force := Vector3(
		(
			(
				float(request["horizontal_position_gain_n_per_m"])
				* (target_center_of_mass.x - center_of_mass.x)
			)
			- float(request["horizontal_velocity_gain_ns_per_m"]) * center_of_mass_velocity.x
		),
		0.0,
		(
			(
				float(request["horizontal_position_gain_n_per_m"])
				* (target_center_of_mass.z - center_of_mass.z)
			)
			- float(request["horizontal_velocity_gain_ns_per_m"]) * center_of_mass_velocity.z
		)
	)
	var maximum_horizontal_force_n := float(request["maximum_horizontal_force_n"])
	if desired_horizontal_force.length() > maximum_horizontal_force_n:
		desired_horizontal_force *= (maximum_horizontal_force_n / desired_horizontal_force.length())
	var vertical_correction_n := (
		(
			float(request["vertical_position_gain_n_per_m"])
			* (target_center_of_mass.y - center_of_mass.y)
		)
		- float(request["vertical_velocity_gain_ns_per_m"]) * center_of_mass_velocity.y
	)
	vertical_correction_n = clampf(
		vertical_correction_n,
		-float(request["maximum_vertical_correction_n"]),
		float(request["maximum_vertical_correction_n"])
	)
	var desired_vertical_force_n := (
		mass_kg * gravity_m_s2 * float(request["declared_supported_weight_fraction"])
		+ vertical_correction_n
	)
	var desired_roll_moment_nm := clampf(
		(
			-float(request["roll_position_gain_nm_per_rad"]) * float(request["torso_roll_rad"])
			- (
				float(request["roll_velocity_gain_nm_s_per_rad"])
				* float(request["torso_roll_rate_rad_s"])
			)
		),
		-float(request["maximum_roll_pitch_moment_nm"]),
		float(request["maximum_roll_pitch_moment_nm"])
	)
	var desired_pitch_moment_nm := clampf(
		(
			-float(request["pitch_position_gain_nm_per_rad"]) * float(request["torso_pitch_rad"])
			- (
				float(request["pitch_velocity_gain_nm_s_per_rad"])
				* float(request["torso_pitch_rate_rad_s"])
			)
		),
		-float(request["maximum_roll_pitch_moment_nm"]),
		float(request["maximum_roll_pitch_moment_nm"])
	)

	var force_x_by_contact: Array[float] = []
	var force_z_by_contact: Array[float] = []
	for _index in range(count):
		force_x_by_contact.append(desired_horizontal_force.x / float(count))
		force_z_by_contact.append(desired_horizontal_force.z / float(count))
	var relative_points: Array[Vector3] = []
	for contact_value in support_contacts:
		var contact: Dictionary = contact_value
		var relative := _vector3(contact["point_world_m"]) - center_of_mass
		relative_points.append(relative)

	# A n = b, with rows for total normal force, roll moment, and pitch moment.
	# For each normal n_i:
	#   Mx = sum(r_y * f_z - r_z * n_i)
	#   Mz = sum(r_x * n_i - r_y * f_x)
	var row_sum: Array[float] = []
	var row_z: Array[float] = []
	var row_x: Array[float] = []
	var preferred_normal_forces: Array[float] = []
	for index in range(count):
		var relative := relative_points[index]
		var contact: Dictionary = support_contacts[index]
		row_sum.append(1.0)
		row_z.append(relative.z)
		row_x.append(relative.x)
		preferred_normal_forces.append(float(contact.get("preferred_normal_force_n", 0.0)))
	var gram_rows := [
		Vector3(_dot(row_sum, row_sum), _dot(row_sum, row_z), _dot(row_sum, row_x)),
		Vector3(_dot(row_z, row_sum), _dot(row_z, row_z), _dot(row_z, row_x)),
		Vector3(_dot(row_x, row_sum), _dot(row_x, row_z), _dot(row_x, row_x)),
	]
	var gram_scale := maxf(
		1.0,
		maxf(
			(gram_rows[0] as Vector3).length(),
			maxf((gram_rows[1] as Vector3).length(), (gram_rows[2] as Vector3).length())
		)
	)
	var gram_determinant := absf(
		(gram_rows[0] as Vector3).dot((gram_rows[1] as Vector3).cross(gram_rows[2] as Vector3))
	)
	if gram_determinant <= 1.0e-9 * gram_scale * gram_scale * gram_scale:
		return _failure("SPATIAL_CENTROIDAL_SUPPORT_GEOMETRY_RANK_DEFICIENT")
	var normal_forces: Array[float] = []
	# Iterate tangential sharing and normal allocation together. Proportional
	# sharing keeps every positive-normal contact at the same friction
	# utilization instead of overloading the lightest contact.
	for iteration in range(5):
		var horizontal_roll_moment_nm := 0.0
		var horizontal_pitch_moment_nm := 0.0
		for index in range(count):
			horizontal_roll_moment_nm += (relative_points[index].y * force_z_by_contact[index])
			horizontal_pitch_moment_nm -= (relative_points[index].y * force_x_by_contact[index])
		var target_constraints := Vector3(
			desired_vertical_force_n,
			horizontal_roll_moment_nm - desired_roll_moment_nm,
			desired_pitch_moment_nm - horizontal_pitch_moment_nm
		)
		var right_hand_side := (
			target_constraints
			- Vector3(
				_dot(row_sum, preferred_normal_forces),
				_dot(row_z, preferred_normal_forces),
				_dot(row_x, preferred_normal_forces)
			)
		)
		var multiplier_result := _solve_3x3(gram_rows, right_hand_side)
		if not bool(multiplier_result.get("ok", false)):
			return _failure("SPATIAL_CENTROIDAL_SUPPORT_GEOMETRY_RANK_DEFICIENT")
		var multipliers: Vector3 = multiplier_result["solution"]
		normal_forces.clear()
		var positive_normal_sum := 0.0
		for index in range(count):
			var normal_n := (
				preferred_normal_forces[index]
				+ row_sum[index] * multipliers.x
				+ row_z[index] * multipliers.y
				+ row_x[index] * multipliers.z
			)
			normal_forces.append(normal_n)
			positive_normal_sum += maxf(normal_n, 0.0)
		if iteration < 4 and positive_normal_sum > _EPSILON:
			for index in range(count):
				var share := maxf(normal_forces[index], 0.0) / positive_normal_sum
				force_x_by_contact[index] = desired_horizontal_force.x * share
				force_z_by_contact[index] = desired_horizontal_force.z * share

	var minimum_normal_n := float(request["minimum_normal_force_n"])
	var maximum_normal_n := float(request["maximum_normal_force_n"])
	var friction_coefficient := float(request["friction_coefficient"])
	var tolerance := float(request["feasibility_tolerance"])
	var infeasibility_reasons: Array[String] = []
	var commands: Dictionary = {}
	var achieved_force := Vector3.ZERO
	var achieved_moment := Vector3.ZERO
	var minimum_normal_reserve_n := INF
	var minimum_friction_reserve_n := INF
	var nominal_normal_n := mass_kg * gravity_m_s2 / float(int(request["nominal_support_count"]))
	for index in range(count):
		var contact: Dictionary = support_contacts[index]
		var contact_id := String(contact["contact_id"])
		var normal_n := normal_forces[index]
		var tangent_n := Vector2(force_x_by_contact[index], force_z_by_contact[index]).length()
		var friction_limit_n := friction_coefficient * maxf(normal_n, 0.0)
		if normal_n < minimum_normal_n - tolerance:
			infeasibility_reasons.append("NORMAL_BELOW_MINIMUM:%s" % contact_id)
		if normal_n > maximum_normal_n + tolerance:
			infeasibility_reasons.append("NORMAL_ABOVE_MAXIMUM:%s" % contact_id)
		if tangent_n > friction_limit_n + tolerance:
			infeasibility_reasons.append("FRICTION_EXCEEDED:%s" % contact_id)
		minimum_normal_reserve_n = minf(minimum_normal_reserve_n, maximum_normal_n - normal_n)
		minimum_friction_reserve_n = minf(minimum_friction_reserve_n, friction_limit_n - tangent_n)
		var external_force := Vector3(
			force_x_by_contact[index], normal_n, force_z_by_contact[index]
		)
		var task_force_delta := Vector3(
			-external_force.x, -(external_force.y - nominal_normal_n), -external_force.z
		)
		var point := _vector3(contact["point_world_m"])
		achieved_force += external_force
		achieved_moment += (point - center_of_mass).cross(external_force)
		commands[contact_id] = {
			"contact_id": contact_id,
			"external_force_command_world_n": external_force,
			"joint_task_force_delta_world_n": task_force_delta,
			"normal_force_command_n": normal_n,
			"tangential_force_command_n": tangent_n,
			"friction_limit_n": friction_limit_n,
			"command_not_measurement": true,
		}

	var desired_force := Vector3(
		desired_horizontal_force.x, desired_vertical_force_n, desired_horizontal_force.z
	)
	var desired_moment := Vector3(desired_roll_moment_nm, 0.0, desired_pitch_moment_nm)
	var force_residual := achieved_force - desired_force
	var roll_pitch_residual := Vector2(
		achieved_moment.x - desired_moment.x, achieved_moment.z - desired_moment.z
	)
	if force_residual.length() > tolerance:
		infeasibility_reasons.append("FORCE_RESIDUAL")
	if roll_pitch_residual.length() > tolerance:
		infeasibility_reasons.append("ROLL_PITCH_MOMENT_RESIDUAL")
	return {
		"ok": true,
		"command":
		{
			"schema_version": "spatial_centroidal_support_command_v1",
			"tick": int(request["tick"]),
			"feasible": infeasibility_reasons.is_empty(),
			"infeasibility_reasons": infeasibility_reasons,
			"desired_external_force_world_n": desired_force,
			"desired_external_roll_pitch_moment_world_nm": desired_moment,
			"achieved_external_force_world_n": achieved_force,
			"achieved_external_moment_world_nm": achieved_moment,
			"force_residual_n": force_residual,
			"roll_pitch_moment_residual_nm": roll_pitch_residual,
			"minimum_normal_reserve_n": minimum_normal_reserve_n,
			"minimum_friction_reserve_n": minimum_friction_reserve_n,
			"support_contact_commands": commands,
			"per_contact_values_are_commands_not_measurements": true,
			"per_foot_measured_load_allocation_available": false,
			"physics_state_modified": false,
		},
	}


static func _validate(request: Dictionary) -> Dictionary:
	var required := [
		"schema_version",
		"tick",
		"whole_system_mass_kg",
		"gravity_m_s2",
		"center_of_mass_world_m",
		"center_of_mass_velocity_world_m_s",
		"target_center_of_mass_world_m",
		"torso_roll_rad",
		"torso_pitch_rad",
		"torso_roll_rate_rad_s",
		"torso_pitch_rate_rad_s",
		"horizontal_position_gain_n_per_m",
		"horizontal_velocity_gain_ns_per_m",
		"vertical_position_gain_n_per_m",
		"vertical_velocity_gain_ns_per_m",
		"roll_position_gain_nm_per_rad",
		"roll_velocity_gain_nm_s_per_rad",
		"pitch_position_gain_nm_per_rad",
		"pitch_velocity_gain_nm_s_per_rad",
		"maximum_horizontal_force_n",
		"maximum_vertical_correction_n",
		"maximum_roll_pitch_moment_nm",
		"declared_supported_weight_fraction",
		"friction_coefficient",
		"minimum_normal_force_n",
		"maximum_normal_force_n",
		"nominal_support_count",
		"feasibility_tolerance",
		"support_contacts",
	]
	for field in required:
		if not request.has(field):
			return _failure("SPATIAL_CENTROIDAL_SUPPORT_FIELD_MISSING:%s" % field)
	if String(request["schema_version"]) != REQUEST_SCHEMA_VERSION:
		return _failure("SPATIAL_CENTROIDAL_SUPPORT_SCHEMA_INVALID")
	for field in [
		"whole_system_mass_kg",
		"gravity_m_s2",
		"horizontal_position_gain_n_per_m",
		"horizontal_velocity_gain_ns_per_m",
		"vertical_position_gain_n_per_m",
		"vertical_velocity_gain_ns_per_m",
		"roll_position_gain_nm_per_rad",
		"roll_velocity_gain_nm_s_per_rad",
		"pitch_position_gain_nm_per_rad",
		"pitch_velocity_gain_nm_s_per_rad",
		"maximum_horizontal_force_n",
		"maximum_vertical_correction_n",
		"maximum_roll_pitch_moment_nm",
		"declared_supported_weight_fraction",
		"friction_coefficient",
		"minimum_normal_force_n",
		"maximum_normal_force_n",
		"feasibility_tolerance",
	]:
		if not is_finite(float(request[field])) or float(request[field]) < 0.0:
			return _failure("SPATIAL_CENTROIDAL_SUPPORT_SCALAR_INVALID:%s" % field)
	if (
		float(request["whole_system_mass_kg"]) <= 0.0
		or float(request["gravity_m_s2"]) <= 0.0
		or float(request["maximum_normal_force_n"]) < float(request["minimum_normal_force_n"])
		or float(request["declared_supported_weight_fraction"]) > 1.0
		or int(request["nominal_support_count"]) < 1
		or float(request["feasibility_tolerance"]) <= 0.0
	):
		return _failure("SPATIAL_CENTROIDAL_SUPPORT_BOUND_INVALID")
	for field in [
		"center_of_mass_world_m",
		"center_of_mass_velocity_world_m_s",
		"target_center_of_mass_world_m",
	]:
		if not _vector3(request[field]).is_finite():
			return _failure("SPATIAL_CENTROIDAL_SUPPORT_VECTOR_INVALID:%s" % field)
	for field in [
		"torso_roll_rad",
		"torso_pitch_rad",
		"torso_roll_rate_rad_s",
		"torso_pitch_rate_rad_s",
	]:
		if not is_finite(float(request[field])):
			return _failure("SPATIAL_CENTROIDAL_SUPPORT_ATTITUDE_INVALID:%s" % field)
	var support_contacts: Array = request["support_contacts"]
	if support_contacts.size() < 3:
		return _failure("SPATIAL_CENTROIDAL_SUPPORT_CONTACT_SET_TOO_SMALL")
	var ids: Dictionary = {}
	for contact_value in support_contacts:
		if typeof(contact_value) != TYPE_DICTIONARY:
			return _failure("SPATIAL_CENTROIDAL_SUPPORT_CONTACT_INVALID")
		var contact: Dictionary = contact_value
		if not contact.has("contact_id") or not contact.has("point_world_m"):
			return _failure("SPATIAL_CENTROIDAL_SUPPORT_CONTACT_FIELD_MISSING")
		var contact_id := String(contact["contact_id"])
		if contact_id.is_empty() or ids.has(contact_id):
			return _failure("SPATIAL_CENTROIDAL_SUPPORT_CONTACT_ID_INVALID")
		ids[contact_id] = true
		if not _vector3(contact["point_world_m"]).is_finite():
			return _failure("SPATIAL_CENTROIDAL_SUPPORT_CONTACT_POINT_INVALID")
		if (
			contact.has("preferred_normal_force_n")
			and (
				not is_finite(float(contact["preferred_normal_force_n"]))
				or float(contact["preferred_normal_force_n"]) < 0.0
			)
		):
			return _failure("SPATIAL_CENTROIDAL_SUPPORT_CONTACT_PREFERENCE_INVALID")
	return {"ok": true}


static func _dot(left: Array[float], right: Array[float]) -> float:
	var value := 0.0
	for index in range(left.size()):
		value += left[index] * right[index]
	return value


static func _solve_3x3(rows: Array, right_hand_side: Vector3) -> Dictionary:
	var values := [
		[
			float((rows[0] as Vector3).x),
			float((rows[0] as Vector3).y),
			float((rows[0] as Vector3).z),
			right_hand_side.x
		],
		[
			float((rows[1] as Vector3).x),
			float((rows[1] as Vector3).y),
			float((rows[1] as Vector3).z),
			right_hand_side.y
		],
		[
			float((rows[2] as Vector3).x),
			float((rows[2] as Vector3).y),
			float((rows[2] as Vector3).z),
			right_hand_side.z
		],
	]
	for column in range(3):
		var pivot_row := column
		for row in range(column + 1, 3):
			if absf(float(values[row][column])) > absf(float(values[pivot_row][column])):
				pivot_row = row
		if absf(float(values[pivot_row][column])) <= _EPSILON:
			return _failure("SPATIAL_CENTROIDAL_SUPPORT_LINEAR_SYSTEM_SINGULAR")
		if pivot_row != column:
			var swap = values[column]
			values[column] = values[pivot_row]
			values[pivot_row] = swap
		var pivot := float(values[column][column])
		for entry in range(column, 4):
			values[column][entry] = float(values[column][entry]) / pivot
		for row in range(3):
			if row == column:
				continue
			var factor := float(values[row][column])
			for entry in range(column, 4):
				values[row][entry] = (
					float(values[row][entry]) - factor * float(values[column][entry])
				)
	return {
		"ok": true,
		"solution": Vector3(float(values[0][3]), float(values[1][3]), float(values[2][3])),
	}


static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	var raw: Array = value
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
