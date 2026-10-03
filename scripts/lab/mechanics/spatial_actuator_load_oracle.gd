class_name LabSpatialActuatorLoadOracle
extends RefCounted
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## Pure BR14A prephysical spatial contact-command to joint-load oracle.
##
## Declared contact-force commands are mapped to revolute joint generalized
## loads with exact J-transpose geometry:
##
##   tau = axis dot ((contact_point - joint_pivot) cross contact_force)
##
## The opposing actuator command is compared with the already accepted BR4
## full-activation torque/speed/power envelope and structural torque limit.
## This is an upper-bound screen. It intentionally does not claim that the
## pose is reachable, collision free, dynamically controllable, or executable
## after activation and torque-rate transients.

const ActuatorSpecScript := preload("res://scripts/lab/mechanics/actuator_spec.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const JointActuatorScript := preload("res://scripts/lab/mechanics/joint_actuator.gd")

const SCHEMA_VERSION := "spatial_actuator_load_request_v1"
const REPORT_SCHEMA_VERSION := "spatial_actuator_load_report_v1"
const POSITIVE_CLAIM := "prephysical_declared_contact_command_to_actuator_envelope_only"
const BIAS_SOURCE := "declared_incomplete_analytic_bias"
const CLAIM_BOUNDARY := (
	"BR14A prephysical declared contact-command to revolute-joint load and "
	+ "full-activation BR4 actuator-envelope screen only. Contact commands "
	+ "are not measured loads. Declared bias torque is explicitly incomplete. "
	+ "The result establishes no complete rigid-body inverse dynamics, "
	+ "activation or torque-rate feasibility, inverse-kinematic reach, "
	+ "collision clearance, structure beyond the declared joint torque cap, "
	+ "dynamic controllability, scaffold removal, canonical morphology, "
	+ "physical stance, bracing, catch, fall arrest, get-up, step, gait, "
	+ "walking, repair, automatic application, or creature guidance."
)
const REQUEST_FIELDS: Array[String] = [
	"schema_version",
	"analysis_id",
	"reference_frame",
	"minimum_joint_limit_margin_rad",
	"contacts",
	"joints",
	"claim_boundary",
	"automatic_creature_guidance_allowed",
]
const CONTACT_FIELDS: Array[String] = [
	"contact_id",
	"point_world_m",
	"force_command_world_n",
	"command_not_measurement",
]
const JOINT_FIELDS: Array[String] = [
	"joint_id",
	"axis_world",
	"pivot_world_m",
	"angular_rate_rad_s",
	"angle_rad",
	"minimum_angle_rad",
	"maximum_angle_rad",
	"downstream_contact_ids",
	"declared_bias_torque_nm",
	"bias_torque_source",
	"full_activation_assumed",
	"actuator_spec",
]
const UNIT_TOLERANCE := 1.0e-6
const CAPACITY_TOLERANCE := 1.0e-9


static func compile(configuration: Dictionary) -> Dictionary:
	var fields := _exact_fields(configuration, REQUEST_FIELDS, "request")
	if not bool(fields.get("ok", false)):
		return fields
	if String(configuration["schema_version"]) != SCHEMA_VERSION:
		return _failure("SPATIAL_ACTUATOR_SCHEMA_INVALID", "Request schema is not recognized.")
	if (
		not _stable_id(String(configuration["analysis_id"]))
		or String(configuration["reference_frame"]) != "centroidal_world"
	):
		return _failure(
			"SPATIAL_ACTUATOR_IDENTITY_INVALID",
			"Stable analysis identity and the centroidal-world frame are required."
		)
	if (
		not _finite_number(configuration["minimum_joint_limit_margin_rad"])
		or float(configuration["minimum_joint_limit_margin_rad"]) < 0.0
		or float(configuration["minimum_joint_limit_margin_rad"]) > PI
	):
		return _failure(
			"SPATIAL_ACTUATOR_LIMIT_POLICY_INVALID",
			"Joint-limit margin must be finite and lie between zero and pi."
		)
	if (
		String(configuration["claim_boundary"]) != CLAIM_BOUNDARY
		or typeof(configuration["automatic_creature_guidance_allowed"]) != TYPE_BOOL
		or bool(configuration["automatic_creature_guidance_allowed"])
	):
		return _failure(
			"SPATIAL_ACTUATOR_CLAIM_BOUNDARY_INVALID",
			"The exact non-capability boundary and false guidance authority are required."
		)
	if (
		typeof(configuration["contacts"]) != TYPE_ARRAY
		or (configuration["contacts"] as Array).is_empty()
		or (configuration["contacts"] as Array).size() > 16
	):
		return _failure(
			"SPATIAL_ACTUATOR_CONTACT_SET_INVALID",
			"Between one and sixteen declared contact commands are required."
		)
	if (
		typeof(configuration["joints"]) != TYPE_ARRAY
		or (configuration["joints"] as Array).is_empty()
		or (configuration["joints"] as Array).size() > 64
	):
		return _failure(
			"SPATIAL_ACTUATOR_JOINT_SET_INVALID",
			"Between one and sixty-four revolute joints are required."
		)

	var contact_ids: Dictionary = {}
	var contact_assignment_counts: Dictionary = {}
	for contact_value in configuration["contacts"]:
		var contact_result := _validate_contact(contact_value)
		if not bool(contact_result.get("ok", false)):
			return contact_result
		var contact: Dictionary = contact_value
		var contact_id := String(contact["contact_id"])
		if contact_ids.has(contact_id):
			return _failure(
				"SPATIAL_ACTUATOR_CONTACT_ID_DUPLICATE",
				"Contact-command identities must be unique."
			)
		contact_ids[contact_id] = true
		contact_assignment_counts[contact_id] = 0

	var joint_ids: Dictionary = {}
	var actuator_ids: Dictionary = {}
	for joint_value in configuration["joints"]:
		var joint_result := _validate_joint(joint_value, contact_ids)
		if not bool(joint_result.get("ok", false)):
			return joint_result
		var joint: Dictionary = joint_value
		var joint_id := String(joint["joint_id"])
		if joint_ids.has(joint_id):
			return _failure(
				"SPATIAL_ACTUATOR_JOINT_ID_DUPLICATE", "Joint identities must be unique."
			)
		joint_ids[joint_id] = true
		var spec: Dictionary = joint["actuator_spec"]
		var actuator_id := String(spec["actuator_id"])
		if actuator_ids.has(actuator_id):
			return _failure(
				"SPATIAL_ACTUATOR_ACTUATOR_ID_DUPLICATE",
				"Actuator identities must be unique across joints."
			)
		actuator_ids[actuator_id] = true
		for contact_id_value in joint["downstream_contact_ids"]:
			var contact_id := String(contact_id_value)
			contact_assignment_counts[contact_id] = int(contact_assignment_counts[contact_id]) + 1
	for contact_id in contact_assignment_counts:
		if int(contact_assignment_counts[contact_id]) == 0:
			return _failure(
				"SPATIAL_ACTUATOR_CONTACT_UNASSIGNED",
				"Every declared contact command must map to at least one joint."
			)

	var sealed := configuration.duplicate(true)
	sealed["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	return {"ok": true, "request": FrozenValueScript.snapshot(sealed)}


static func analyze(compiled_value: Variant) -> Dictionary:
	if typeof(compiled_value) != TYPE_DICTIONARY:
		return _failure("SPATIAL_ACTUATOR_REQUEST_INVALID", "Compiled request must be one object.")
	var compiled: Dictionary = compiled_value
	if not compiled.has("configuration_sha256"):
		return _failure("SPATIAL_ACTUATOR_DIGEST_MISSING", "Compiled request digest is missing.")
	var raw := compiled.duplicate(true)
	var digest := String(raw["configuration_sha256"])
	raw.erase("configuration_sha256")
	var recompiled := compile(raw)
	if (
		not bool(recompiled.get("ok", false))
		or String((recompiled["request"] as Dictionary)["configuration_sha256"]) != digest
	):
		return _failure(
			"SPATIAL_ACTUATOR_DIGEST_MISMATCH",
			"Compiled request differs from its sealed configuration."
		)

	var contacts: Dictionary = {}
	for contact_value in compiled["contacts"]:
		var contact: Dictionary = contact_value
		contacts[String(contact["contact_id"])] = contact

	var joint_reports: Array = []
	var screen_passed := true
	for joint_value in compiled["joints"]:
		var joint: Dictionary = joint_value
		var axis := _vector3(joint["axis_world"])
		var pivot := _vector3(joint["pivot_world_m"])
		var contact_generalized_load := 0.0
		var contributions: Array = []
		for contact_id_value in joint["downstream_contact_ids"]:
			var contact_id := String(contact_id_value)
			var contact: Dictionary = contacts[contact_id]
			var point := _vector3(contact["point_world_m"])
			var force := _vector3(contact["force_command_world_n"])
			var contribution := axis.dot((point - pivot).cross(force))
			contact_generalized_load += contribution
			(
				contributions
				. append(
					{
						"contact_id": contact_id,
						"generalized_load_nm": contribution,
						"command_not_measurement": true,
					}
				)
			)
		var bias := float(joint["declared_bias_torque_nm"])
		var required_active := -(contact_generalized_load + bias)
		var spec: Dictionary = joint["actuator_spec"]
		var angular_rate := float(joint["angular_rate_rad_s"])
		var bounds := JointActuatorScript.active_bounds_nm(1.0, angular_rate, spec)
		var lower := float(bounds["lower_nm"])
		var upper := float(bounds["upper_nm"])
		var actuator_envelope_passed := (
			required_active >= lower - CAPACITY_TOLERANCE
			and required_active <= upper + CAPACITY_TOLERANCE
		)
		var structural_cap := float(spec["structural_torque_limit_nm"])
		var structural_cap_passed := absf(required_active) <= structural_cap + CAPACITY_TOLERANCE
		var lower_limit_margin := float(joint["angle_rad"]) - float(joint["minimum_angle_rad"])
		var upper_limit_margin := float(joint["maximum_angle_rad"]) - float(joint["angle_rad"])
		var minimum_limit_margin := minf(lower_limit_margin, upper_limit_margin)
		var joint_limit_passed := (
			minimum_limit_margin
			>= float(compiled["minimum_joint_limit_margin_rad"]) - CAPACITY_TOLERANCE
		)
		var joint_passed := (
			actuator_envelope_passed and structural_cap_passed and joint_limit_passed
		)
		screen_passed = screen_passed and joint_passed
		var directional_capacity := upper if required_active >= 0.0 else -lower
		var directional_capacity_available := directional_capacity > CAPACITY_TOLERANCE
		var utilization := (
			absf(required_active) / directional_capacity if directional_capacity_available else 0.0
		)
		var work_regime := "isometric"
		if required_active * angular_rate > CAPACITY_TOLERANCE:
			work_regime = "positive_work"
		elif required_active * angular_rate < -CAPACITY_TOLERANCE:
			work_regime = "negative_work"
		var selected_curve: Dictionary = bounds["positive_work"]
		if work_regime == "negative_work":
			selected_curve = bounds["negative_work"]
		(
			joint_reports
			. append(
				{
					"joint_id": joint["joint_id"],
					"actuator_id": spec["actuator_id"],
					"actuator_spec_sha256": spec["spec_sha256"],
					"contact_generalized_load_nm": contact_generalized_load,
					"declared_bias_torque_nm": bias,
					"declared_bias_is_complete": false,
					"required_active_torque_nm": required_active,
					"angular_rate_rad_s": angular_rate,
					"active_power_w": required_active * angular_rate,
					"work_regime": work_regime,
					"full_activation_lower_bound_nm": lower,
					"full_activation_upper_bound_nm": upper,
					"directional_capacity_nm": directional_capacity,
					"directional_capacity_available": directional_capacity_available,
					"directional_capacity_utilization": utilization,
					"speed_curve_is_active_bound": bool(selected_curve["speed_limited"]),
					"power_cap_is_active_bound": bool(selected_curve["power_limited"]),
					"structural_torque_limit_nm": structural_cap,
					"minimum_joint_limit_margin_rad": minimum_limit_margin,
					"contact_contributions": contributions,
					"actuator_envelope_passed": actuator_envelope_passed,
					"structural_cap_passed": structural_cap_passed,
					"joint_limit_passed": joint_limit_passed,
					"joint_screen_passed": joint_passed,
				}
			)
		)

	var report := {
		"schema_version": REPORT_SCHEMA_VERSION,
		"analysis_id": compiled["analysis_id"],
		"configuration_sha256": digest,
		"reference_frame": "centroidal_world",
		"contact_count": contacts.size(),
		"joint_count": joint_reports.size(),
		"joint_reports": joint_reports,
		"screen_passed": screen_passed,
		"positive_claim": POSITIVE_CLAIM,
		"claim_boundary": CLAIM_BOUNDARY,
		"j_transpose_geometry_applied": true,
		"full_activation_upper_bound_only": true,
		"contact_commands_are_measurements": false,
		"contact_feasibility_established_by_this_oracle": false,
		"declared_bias_terms_complete": false,
		"complete_rigid_body_inverse_dynamics_established": false,
		"activation_or_torque_rate_feasibility_established": false,
		"inverse_kinematic_reach_established": false,
		"collision_clearance_established": false,
		"canonical_morphology_selected": false,
		"physical_stance_or_recovery_established": false,
		"step_gait_or_walking_established": false,
		"automatic_creature_guidance_allowed": false,
	}
	report["report_sha256"] = CanonicalJsonScript.sha256(report)
	return {"ok": true, "report": FrozenValueScript.snapshot(report)}


static func _validate_contact(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("SPATIAL_ACTUATOR_CONTACT_INVALID", "Every contact must be one object.")
	var contact: Dictionary = value
	var fields := _exact_fields(contact, CONTACT_FIELDS, "contact")
	if not bool(fields.get("ok", false)):
		return fields
	if not _stable_id(String(contact["contact_id"])):
		return _failure("SPATIAL_ACTUATOR_CONTACT_ID_INVALID", "Contact ID must be stable.")
	for field in ["point_world_m", "force_command_world_n"]:
		var vector := _strict_vector3(contact[field])
		if not bool(vector.get("ok", false)):
			return vector
	if (
		typeof(contact["command_not_measurement"]) != TYPE_BOOL
		or not bool(contact["command_not_measurement"])
	):
		return _failure(
			"SPATIAL_ACTUATOR_CONTACT_AUTHORITY_INVALID",
			"Every force must remain explicitly a command rather than a measurement."
		)
	return {"ok": true}


static func _validate_joint(value: Variant, contact_ids: Dictionary) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("SPATIAL_ACTUATOR_JOINT_INVALID", "Every joint must be one object.")
	var joint: Dictionary = value
	var fields := _exact_fields(joint, JOINT_FIELDS, "joint")
	if not bool(fields.get("ok", false)):
		return fields
	if not _stable_id(String(joint["joint_id"])):
		return _failure("SPATIAL_ACTUATOR_JOINT_ID_INVALID", "Joint ID must be stable.")
	var axis_result := _strict_vector3(joint["axis_world"])
	var pivot_result := _strict_vector3(joint["pivot_world_m"])
	if not bool(axis_result.get("ok", false)) or not bool(pivot_result.get("ok", false)):
		return _failure(
			"SPATIAL_ACTUATOR_JOINT_FRAME_INVALID", "Joint axis and pivot must be finite vectors."
		)
	var axis := _vector3(joint["axis_world"])
	if absf(axis.length() - 1.0) > UNIT_TOLERANCE:
		return _failure("SPATIAL_ACTUATOR_JOINT_AXIS_INVALID", "Joint axis must be a unit vector.")
	for field in [
		"angular_rate_rad_s",
		"angle_rad",
		"minimum_angle_rad",
		"maximum_angle_rad",
		"declared_bias_torque_nm",
	]:
		if not _finite_number(joint[field]):
			return _failure(
				"SPATIAL_ACTUATOR_JOINT_NUMERIC_INVALID",
				"Joint state, limits, rate, and bias must be finite."
			)
	if float(joint["minimum_angle_rad"]) >= float(joint["maximum_angle_rad"]):
		return _failure(
			"SPATIAL_ACTUATOR_JOINT_LIMITS_INVALID",
			"Joint minimum angle must be below its maximum angle."
		)
	if (
		String(joint["bias_torque_source"]) != BIAS_SOURCE
		or typeof(joint["full_activation_assumed"]) != TYPE_BOOL
		or not bool(joint["full_activation_assumed"])
	):
		return _failure(
			"SPATIAL_ACTUATOR_ASSUMPTION_INVALID",
			"The exact incomplete-bias and full-activation assumptions are required."
		)
	if (
		typeof(joint["downstream_contact_ids"]) != TYPE_ARRAY
		or (joint["downstream_contact_ids"] as Array).is_empty()
	):
		return _failure(
			"SPATIAL_ACTUATOR_CONTACT_MAP_INVALID",
			"Every joint must name at least one downstream contact."
		)
	var seen_contacts: Dictionary = {}
	for contact_id_value in joint["downstream_contact_ids"]:
		if typeof(contact_id_value) not in [TYPE_STRING, TYPE_STRING_NAME]:
			return _failure(
				"SPATIAL_ACTUATOR_CONTACT_MAP_INVALID",
				"Downstream contact identities must be strings."
			)
		var contact_id := String(contact_id_value)
		if not contact_ids.has(contact_id) or seen_contacts.has(contact_id):
			return _failure(
				"SPATIAL_ACTUATOR_CONTACT_MAP_INVALID",
				"Downstream contacts must exist and be unique within each joint."
			)
		seen_contacts[contact_id] = true
	if typeof(joint["actuator_spec"]) != TYPE_DICTIONARY:
		return _failure(
			"SPATIAL_ACTUATOR_SPEC_INVALID", "Every joint requires one compiled actuator spec."
		)
	var spec_result := ActuatorSpecScript.verify(joint["actuator_spec"])
	if not bool(spec_result.get("ok", false)):
		return _failure(
			"SPATIAL_ACTUATOR_SPEC_INVALID",
			"Every actuator spec must verify under the accepted BR4 contract."
		)
	return {"ok": true}


static func _strict_vector3(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != 3:
		return _failure(
			"SPATIAL_ACTUATOR_VECTOR_INVALID", "Spatial vectors must contain three values."
		)
	for component in value:
		if not _finite_number(component):
			return _failure(
				"SPATIAL_ACTUATOR_VECTOR_INVALID", "Spatial vectors must be finite and numeric."
			)
	return {"ok": true}


static func _vector3(value: Variant) -> Vector3:
	var array: Array = value
	return Vector3(float(array[0]), float(array[1]), float(array[2]))


static func _exact_fields(value: Dictionary, expected: Array[String], label: String) -> Dictionary:
	if value.size() != expected.size():
		return _failure(
			"SPATIAL_ACTUATOR_FIELDS_INVALID", "%s field set is not exact." % label.capitalize()
		)
	for field in expected:
		if not value.has(field):
			return _failure(
				"SPATIAL_ACTUATOR_FIELDS_INVALID",
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
