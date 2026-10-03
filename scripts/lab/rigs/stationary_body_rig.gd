class_name LabStationaryBodyRig
extends RefCounted

const ObservedRigidBodyScript := preload(
	"res://scripts/lab/mechanics/observed_rigid_body.gd")

const FIXTURE_ID := "L0.0.stationary_gravity_off.v1"
const BODY_ID := &"body_0"
const BODY_PARAMETER_KEYS := [
	"mass_kg",
	"gravity_scale",
	"initial_position_m",
	"initial_velocity_m_s",
	"linear_damp_s1",
	"angular_damp_s1",
]
const FIXTURE_PARAMETER_KEYS := [
	"contact_cap",
]


static func build(
		capture_clock,
		observer_profile: Dictionary,
		body_parameters: Dictionary = {},
		fixture_parameters: Dictionary = {}) -> Dictionary:
	return _build_isolated_body(
		capture_clock,
		observer_profile,
		Vector3(0.25, 1.75, -0.5),
		Vector3.ZERO,
		0.0,
		FIXTURE_ID,
		body_parameters,
		fixture_parameters)


static func _build_isolated_body(
		capture_clock,
		observer_profile: Dictionary,
		initial_position: Vector3,
		initial_velocity: Vector3,
		gravity_scale: float,
		fixture_id: String,
		body_parameters: Dictionary = {},
		fixture_parameters: Dictionary = {}) -> Dictionary:
	var errors: Array[Dictionary] = []
	var normalized_body := _normalize_parameters(
		body_parameters,
		BODY_PARAMETER_KEYS,
		"body_parameters",
		errors)
	var normalized_fixture := _normalize_parameters(
		fixture_parameters,
		FIXTURE_PARAMETER_KEYS,
		"fixture_parameters",
		errors)
	var resolved_body := {
		"mass_kg": normalized_body.get("mass_kg", 2.0),
		"gravity_scale": normalized_body.get("gravity_scale", gravity_scale),
		"initial_position_m": normalized_body.get(
			"initial_position_m", initial_position),
		"initial_velocity_m_s": normalized_body.get(
			"initial_velocity_m_s", initial_velocity),
		"linear_damp_s1": normalized_body.get("linear_damp_s1", 0.0),
		"angular_damp_s1": normalized_body.get("angular_damp_s1", 0.0),
	}
	_validate_body_parameters(resolved_body, errors)
	var profile_configuration := _validate_contact_configuration(
		observer_profile,
		normalized_fixture,
		errors)
	if not errors.is_empty():
		return {
			"ok": false,
			"configuration_valid": false,
			"fixture_id": fixture_id,
			"body_id": String(BODY_ID),
			"configuration_errors": errors,
			"requested_body_parameters": body_parameters.duplicate(true),
			"requested_fixture_parameters":
				fixture_parameters.duplicate(true),
		}

	var world := Node3D.new()
	world.name = "LabWorld_%s" % fixture_id
	var body = ObservedRigidBodyScript.new()
	body.name = "ObservedBody0"
	body.body_id = BODY_ID
	body.part_index = 0
	body.capture_clock = capture_clock
	body.observer_profile = observer_profile.duplicate(true)
	body.mass = float(resolved_body["mass_kg"])
	body.gravity_scale = float(resolved_body["gravity_scale"])
	body.can_sleep = false
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = float(resolved_body["linear_damp_s1"])
	body.angular_damp = float(resolved_body["angular_damp_s1"])
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = resolved_body["initial_position_m"]
	body.linear_velocity = resolved_body["initial_velocity_m_s"]
	body.angular_velocity = Vector3.ZERO

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4, 0.6, 0.3)
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	return {
		"ok": true,
		"configuration_valid": true,
		"fixture_id": fixture_id,
		"world": world,
		"body": body,
		"body_id": String(BODY_ID),
		"initial_position_m": body.position,
		"initial_velocity_m_s": body.linear_velocity,
		"gravity_scale": body.gravity_scale,
		"mass_kg": body.mass,
		"requested_body_parameters": body_parameters.duplicate(true),
		"requested_fixture_parameters": fixture_parameters.duplicate(true),
		"resolved_body_parameters": {
			"mass_kg": float(resolved_body["mass_kg"]),
			"gravity_scale": float(resolved_body["gravity_scale"]),
			"initial_position_m":
				resolved_body["initial_position_m"],
			"initial_velocity_m_s":
				resolved_body["initial_velocity_m_s"],
			"linear_damp_s1": float(resolved_body["linear_damp_s1"]),
			"angular_damp_s1": float(resolved_body["angular_damp_s1"]),
		},
		"applied_body_parameters": {
			"mass_kg": body.mass,
			"gravity_scale": body.gravity_scale,
			"initial_position_m": body.position,
			"initial_velocity_m_s": body.linear_velocity,
			"linear_damp_s1": body.linear_damp,
			"angular_damp_s1": body.angular_damp,
		},
		"applied_fixture_parameters": profile_configuration,
		"configuration_errors": [],
	}


static func _normalize_parameters(
		source: Dictionary,
		allowed_keys: Array,
		group_name: String,
		errors: Array[Dictionary]) -> Dictionary:
	var normalized: Dictionary = {}
	for raw_key in source.keys():
		if typeof(raw_key) not in [TYPE_STRING, TYPE_STRING_NAME]:
			_add_error(
				errors,
				"INVALID_PARAMETER_KEY",
				"/%s" % group_name,
				"Parameter keys must be strings")
			continue
		var key := String(raw_key)
		if normalized.has(key):
			_add_error(
				errors,
				"DUPLICATE_PARAMETER_KEY",
				"/%s/%s" % [group_name, key],
				"Parameter key is duplicated after normalization")
			continue
		if not allowed_keys.has(key):
			_add_error(
				errors,
				"UNKNOWN_PARAMETER",
				"/%s/%s" % [group_name, key],
				"Parameter is not supported by this isolated-body fixture")
			continue
		normalized[key] = source[raw_key]
	return normalized


static func _validate_body_parameters(
		parameters: Dictionary,
		errors: Array[Dictionary]) -> void:
	for key in [
		"mass_kg",
		"gravity_scale",
		"linear_damp_s1",
		"angular_damp_s1",
	]:
		var value: Variant = parameters[key]
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
			_add_error(
				errors,
				"PARAMETER_TYPE_ERROR",
				"/body_parameters/%s" % key,
				"Expected a finite number")
			continue
		if not is_finite(float(value)):
			_add_error(
				errors,
				"PARAMETER_NONFINITE",
				"/body_parameters/%s" % key,
				"Expected a finite number")
	if (
		typeof(parameters["mass_kg"]) in [TYPE_INT, TYPE_FLOAT]
		and is_finite(float(parameters["mass_kg"]))
		and float(parameters["mass_kg"]) <= 0.0
	):
		_add_error(
			errors,
			"PARAMETER_DOMAIN_ERROR",
			"/body_parameters/mass_kg",
			"Mass must be greater than zero")
	for key in ["linear_damp_s1", "angular_damp_s1"]:
		if (
			typeof(parameters[key]) in [TYPE_INT, TYPE_FLOAT]
			and is_finite(float(parameters[key]))
			and float(parameters[key]) < 0.0
		):
			_add_error(
				errors,
				"PARAMETER_DOMAIN_ERROR",
				"/body_parameters/%s" % key,
				"Damping must be non-negative")
	for key in ["initial_position_m", "initial_velocity_m_s"]:
		var value: Variant = parameters[key]
		if typeof(value) != TYPE_VECTOR3:
			_add_error(
				errors,
				"PARAMETER_TYPE_ERROR",
				"/body_parameters/%s" % key,
				"Expected a finite Vector3")
		else:
			var vector: Vector3 = value
			if not vector.is_finite():
				_add_error(
					errors,
					"PARAMETER_NONFINITE",
					"/body_parameters/%s" % key,
					"Expected a finite Vector3")


static func _validate_contact_configuration(
		observer_profile: Dictionary,
		fixture_parameters: Dictionary,
		errors: Array[Dictionary]) -> Dictionary:
	var profile_contacts: Variant = observer_profile.get(
		"contacts_enabled", null)
	var profile_cap_value: Variant = observer_profile.get(
		"contact_cap_per_body", null)
	if typeof(profile_contacts) != TYPE_BOOL:
		_add_error(
			errors,
			"OBSERVER_PROFILE_MISMATCH",
			"/observer_profile/contacts_enabled",
			"Observer profile must explicitly declare contacts_enabled")
	if typeof(profile_cap_value) != TYPE_INT:
		_add_error(
			errors,
			"OBSERVER_PROFILE_MISMATCH",
			"/observer_profile/contact_cap_per_body",
			"Observer profile contact cap must be an integer")
	var profile_cap := (
		int(profile_cap_value) if typeof(profile_cap_value) == TYPE_INT else -1)
	if profile_cap < 0:
		_add_error(
			errors,
			"OBSERVER_PROFILE_MISMATCH",
			"/observer_profile/contact_cap_per_body",
			"Observer profile contact cap must be non-negative")
	if typeof(profile_contacts) == TYPE_BOOL:
		if bool(profile_contacts) and profile_cap <= 0:
			_add_error(
				errors,
				"OBSERVER_PROFILE_MISMATCH",
				"/observer_profile/contact_cap_per_body",
				"Contact-enabled profiles require a positive cap")
		elif not bool(profile_contacts) and profile_cap != 0:
			_add_error(
				errors,
				"OBSERVER_PROFILE_MISMATCH",
				"/observer_profile/contact_cap_per_body",
				"Contact-disabled profiles require a zero cap")

	var fixture_cap_value: Variant = fixture_parameters.get(
		"contact_cap", profile_cap)
	if typeof(fixture_cap_value) != TYPE_INT:
		_add_error(
			errors,
			"PARAMETER_TYPE_ERROR",
			"/fixture_parameters/contact_cap",
			"Fixture contact cap must be an integer")
	var fixture_cap := (
		int(fixture_cap_value)
			if typeof(fixture_cap_value) == TYPE_INT
			else -1)
	if fixture_cap < 0:
		_add_error(
			errors,
			"PARAMETER_DOMAIN_ERROR",
			"/fixture_parameters/contact_cap",
			"Fixture contact cap must be non-negative")
	if profile_cap >= 0 and fixture_cap >= 0 and profile_cap > fixture_cap:
		_add_error(
			errors,
			"CONTACT_CAP_INCOMPATIBLE",
			"/fixture_parameters/contact_cap",
			"Observer profile cap %d exceeds fixture upper bound %d"
				% [profile_cap, fixture_cap])
	return {
		"contact_cap": fixture_cap,
		"profile_contact_cap_per_body": profile_cap,
		"effective_contact_cap_per_body": profile_cap,
		"contacts_enabled": (
			bool(profile_contacts)
				if typeof(profile_contacts) == TYPE_BOOL
				else false),
	}


static func _add_error(
		errors: Array[Dictionary],
		code: String,
		path: String,
		message: String) -> void:
	errors.append({
		"code": code,
		"path": path,
		"message": message,
	})
