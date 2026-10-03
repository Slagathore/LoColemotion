class_name LabExecutionContractRegistry
extends RefCounted

## Exact BR1 execution compatibility. A scientific parameter may not enter an
## expanded spec unless the selected runner has an explicit physical consumer
## for it. This prevents a manifest from claiming an override that the rig
## silently ignores.

const _COMMON_BODY_PARAMETERS := [
	"mass_kg",
	"gravity_scale",
	"initial_position_m",
	"initial_velocity_m_s",
	"linear_damp_s1",
	"angular_damp_s1",
]

const _CONTRACTS := {
	"L0_0_STATIONARY_GRAVITY_OFF": {
		"fixture_id": "stationary_body_v1",
		"fixture_version": 1,
		"controller_id": "none",
		"observer_profile_ids": ["full_contacts_v1"],
		"body_parameters": _COMMON_BODY_PARAMETERS,
		"fixture_parameters": ["contact_cap"],
		"gate_parameters": [
			"external_work_j",
			"max_position_error_m",
			"max_velocity_error_m_s",
			"total_contact_count",
		],
	},
	"L0_1_FREE_FALL": {
		"fixture_id": "free_fall_body_v1",
		"fixture_version": 1,
		"controller_id": "none",
		"observer_profile_ids": ["full_contacts_v1"],
		"body_parameters": _COMMON_BODY_PARAMETERS,
		"fixture_parameters": ["contact_cap"],
		"gate_parameters": [
			"max_acceleration_error_m_s2",
			"max_position_error_m",
			"max_velocity_error_m_s",
		],
	},
	"L0_2_BALLISTIC_ZERO_G": {
		"fixture_id": "ballistic_body_v1",
		"fixture_version": 1,
		"controller_id": "none",
		"observer_profile_ids": ["full_contacts_v1"],
		"body_parameters": _COMMON_BODY_PARAMETERS,
		"fixture_parameters": ["contact_cap"],
		"gate_parameters": [
			"max_momentum_error_kg_m_s",
			"max_position_error_m",
			"max_velocity_error_m_s",
		],
	},
	"L0_3_OBSERVER_AB": {
		"fixture_id": "observer_ab_ballistic_v1",
		"fixture_version": 1,
		"controller_id": "none",
		"observer_profile_ids": ["full_contacts_v1"],
		"body_parameters": _COMMON_BODY_PARAMETERS,
		"fixture_parameters": ["contact_cap"],
		"gate_parameters": [
			"max_contact_profile_position_delta_m",
			"max_contact_profile_velocity_delta_m_s",
			"max_position_delta_m",
			"max_velocity_delta_m_s",
		],
	},
	"L0_4_TRACE_PLAYBACK": {
		"fixture_id": "trace_playback_v1",
		"fixture_version": 1,
		"controller_id": "none",
		"observer_profile_ids": ["minimal_state_v1"],
		"body_parameters": [],
		"fixture_parameters": [],
		"gate_parameters": ["replay_mismatch_count"],
	},
}


static func validate(expanded: Dictionary) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	var experiment_id := String(expanded.get("experiment_id", ""))
	if not _CONTRACTS.has(experiment_id):
		_error(
			errors,
			"EXPERIMENT_NOT_EXECUTABLE",
			"/experiment_id",
			"No versioned runner contract exists for this experiment")
		return errors
	var contract: Dictionary = _CONTRACTS[experiment_id]
	_exact_value(
		expanded,
		"fixture_id",
		contract["fixture_id"],
		"EXPERIMENT_FIXTURE_INCOMPATIBLE",
		errors)
	_exact_value(
		expanded,
		"fixture_version",
		contract["fixture_version"],
		"FIXTURE_VERSION_INCOMPATIBLE",
		errors)
	_exact_value(
		expanded,
		"controller_id",
		contract["controller_id"],
		"EXPERIMENT_CONTROLLER_INCOMPATIBLE",
		errors)
	if not contract["observer_profile_ids"].has(
			String(expanded.get("observer_profile_id", ""))):
		_error(
			errors,
			"EXPERIMENT_OBSERVER_INCOMPATIBLE",
			"/observer_profile_id",
			"Observer profile is not executable for this experiment contract")
	_exact_parameter_set(
		expanded,
		"body_parameters",
		contract["body_parameters"],
		errors)
	_exact_parameter_set(
		expanded,
		"fixture_parameters",
		contract["fixture_parameters"],
		errors)
	_exact_parameter_set(
		expanded,
		"gate_parameters",
		contract["gate_parameters"],
		errors)
	var controller_parameters: Variant = expanded.get("controller_parameters", {})
	if typeof(controller_parameters) != TYPE_DICTIONARY \
			or not (controller_parameters as Dictionary).is_empty():
		_error(
			errors,
			"CONTROLLER_PARAMETERS_NOT_EXECUTABLE",
			"/controller_parameters",
			"controller_id=none requires an empty controller parameter map")

	if experiment_id != "L0_4_TRACE_PLAYBACK":
		_validate_body_domains(expanded.get("body_parameters", {}), errors)
		_validate_fixture_domains(
			expanded.get("fixture_parameters", {}),
			expanded.get("observer_profile", {}),
			errors)
		_validate_nonnegative_gate_values(
			expanded.get("gate_parameters", {}), errors)
	return errors


static func _exact_value(
		expanded: Dictionary,
		field: String,
		expected: Variant,
		code: String,
		errors: Array[Dictionary]) -> void:
	if expanded.get(field) != expected:
		_error(
			errors,
			code,
			"/%s" % field,
			"Expected %s for %s" % [str(expected), field])


static func _exact_parameter_set(
		expanded: Dictionary,
		group_name: String,
		expected_keys: Array,
		errors: Array[Dictionary]) -> void:
	var value: Variant = expanded.get(group_name, null)
	if typeof(value) != TYPE_DICTIONARY:
		return
	var parameters: Dictionary = value
	for expected_key in expected_keys:
		if not parameters.has(expected_key):
			_error(
				errors,
				"REQUIRED_EXECUTION_PARAMETER_MISSING",
				"/%s/%s" % [group_name, expected_key],
				"Runner contract requires this parameter")
	for key_value in parameters:
		var key := String(key_value)
		if not expected_keys.has(key):
			_error(
				errors,
				"PARAMETER_HAS_NO_EXECUTION_CONSUMER",
				"/%s/%s" % [group_name, key],
				"No physical runner or gate consumes this parameter")


static func _validate_body_domains(
		value: Variant,
		errors: Array[Dictionary]) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		return
	var body: Dictionary = value
	for key in ["mass_kg", "gravity_scale", "linear_damp_s1", "angular_damp_s1"]:
		if typeof(body.get(key)) not in [TYPE_INT, TYPE_FLOAT]:
			_error(
				errors,
				"EXECUTION_PARAMETER_TYPE_INVALID",
				"/body_parameters/%s" % key,
				"Expected a finite number")
	if float(body.get("mass_kg", 0.0)) <= 0.0:
		_error(
			errors,
			"EXECUTION_PARAMETER_DOMAIN_INVALID",
			"/body_parameters/mass_kg",
			"Mass must be greater than zero")
	for key in ["gravity_scale", "linear_damp_s1", "angular_damp_s1"]:
		if float(body.get(key, -1.0)) < 0.0:
			_error(
				errors,
				"EXECUTION_PARAMETER_DOMAIN_INVALID",
				"/body_parameters/%s" % key,
				"%s must be non-negative" % key)
	for key in ["initial_position_m", "initial_velocity_m_s"]:
		var vector: Variant = body.get(key)
		if not (
			vector is Vector3
			or (vector is Array and vector.size() == 3)
		):
			_error(
				errors,
				"EXECUTION_PARAMETER_TYPE_INVALID",
				"/body_parameters/%s" % key,
				"Expected one three-component vector")


static func _validate_fixture_domains(
		value: Variant,
		observer_profile: Variant,
		errors: Array[Dictionary]) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		return
	var fixture: Dictionary = value
	var cap := int(fixture.get("contact_cap", -1))
	if cap < 0:
		_error(
			errors,
			"EXECUTION_PARAMETER_DOMAIN_INVALID",
			"/fixture_parameters/contact_cap",
			"Contact cap must be non-negative")
	if typeof(observer_profile) == TYPE_DICTIONARY:
		var requested_cap := int(
			(observer_profile as Dictionary).get("contact_cap_per_body", 0))
		if requested_cap > cap:
			_error(
				errors,
				"OBSERVER_CONTACT_CAP_EXCEEDS_FIXTURE",
				"/fixture_parameters/contact_cap",
				"Fixture cap is below the selected observer profile cap")


static func _validate_nonnegative_gate_values(
		value: Variant,
		errors: Array[Dictionary]) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		return
	for key_value in (value as Dictionary):
		var key := String(key_value)
		var number: Variant = value[key_value]
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or float(number) < 0.0:
			_error(
				errors,
				"GATE_PARAMETER_DOMAIN_INVALID",
				"/gate_parameters/%s" % key,
				"Gate tolerances and counts must be non-negative numbers")


static func _error(
		errors: Array[Dictionary],
		code: String,
		path: String,
		message: String) -> void:
	errors.append({
		"code": code,
		"path": path,
		"message": message,
	})
