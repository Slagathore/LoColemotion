class_name LabHardLimitReactionAnalyzer
extends RefCounted

## L2.5 hard-limit reaction classifier.
##
## With no actuator, passive element, gravity, damping, or contact, a measured
## change in relative angular momentum at the configured boundary is classified
## only as an internal constraint reaction.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const CONFIGURATION_SCHEMA_VERSION := "hard_limit_reaction_configuration_v1"
const RESULT_SCHEMA_VERSION := "hard_limit_reaction_analysis_v1"
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"trial_id",
	"physics_hz",
	"sample_ticks",
	"initial_relative_rate_rad_s",
	"lower_limit_rad",
	"upper_limit_rad",
	"limit_enabled",
	"parent_mass_kg",
	"parent_size_m",
	"child_mass_kg",
	"child_size_m",
	"gravity_enabled",
	"contact_enabled",
	"built_in_motor_enabled",
	"active_torque_enabled",
	"passive_torque_enabled",
]
const CLAIM_BOUNDARY := (
	"Exact gravity-off, contact-free coaxial free-hinge hard-limit fixture only; "
	+ "the inferred boundary impulse is a constraint reaction, never motor torque "
	+ "or passive strength, and proves no load bearing, standing, bracing, recovery, "
	+ "gait, or walking."
)


static func build(configuration: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var keys: Array = configuration.keys()
	keys.sort()
	var expected: Array = REQUIRED_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		errors.append("HARD_LIMIT_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != CONFIGURATION_SCHEMA_VERSION:
		errors.append("HARD_LIMIT_SCHEMA_UNSUPPORTED")
	if not _stable_id(String(configuration.get("trial_id", ""))):
		errors.append("HARD_LIMIT_TRIAL_ID_INVALID")
	var hz := _positive_integer(configuration.get("physics_hz"))
	var ticks := _positive_integer(configuration.get("sample_ticks"))
	if hz < 60 or hz > 240 or ticks < 10 or ticks > hz:
		errors.append("HARD_LIMIT_SCHEDULE_INVALID")
	var rate := float(configuration.get("initial_relative_rate_rad_s", NAN))
	if not is_finite(rate) or absf(rate) < 0.5 or absf(rate) > 10.0:
		errors.append("HARD_LIMIT_INITIAL_RATE_INVALID")
	var lower := float(configuration.get("lower_limit_rad", NAN))
	var upper := float(configuration.get("upper_limit_rad", NAN))
	if not is_finite(lower) or not is_finite(upper) or lower >= -0.05 or upper <= 0.05:
		errors.append("HARD_LIMIT_BOUNDS_INVALID")
	for field in ["parent_mass_kg", "child_mass_kg"]:
		if not _finite_number(configuration.get(field)) or float(configuration[field]) <= 0.0:
			errors.append("%s_INVALID" % String(field).to_upper())
	var parent_size := _vector3(configuration.get("parent_size_m"))
	var child_size := _vector3(configuration.get("child_size_m"))
	if not _positive_vector(parent_size) or not _positive_vector(child_size):
		errors.append("HARD_LIMIT_BODY_SIZE_INVALID")
	for flag in [
		"gravity_enabled",
		"contact_enabled",
		"built_in_motor_enabled",
		"active_torque_enabled",
		"passive_torque_enabled",
	]:
		if configuration.get(flag) != false:
			errors.append("%s_FORBIDDEN" % flag.to_upper())
	if not configuration.get("limit_enabled") is bool:
		errors.append("HARD_LIMIT_ENABLED_TYPE_INVALID")
	if not errors.is_empty():
		return {
			"ok": false,
			"failure_code": "HARD_LIMIT_CONFIGURATION_INVALID",
			"errors": errors,
		}
	var parent_inertia := (
		float(configuration["parent_mass_kg"])
		* (parent_size.x * parent_size.x + parent_size.y * parent_size.y)
		/ 12.0
	)
	var child_inertia := (
		float(configuration["child_mass_kg"])
		* (child_size.x * child_size.x + child_size.y * child_size.y)
		/ 12.0
	)
	var payload := configuration.duplicate(true)
	payload["analytic_reflected_inertia_kg_m2"] = (
		1.0 / (1.0 / parent_inertia + 1.0 / child_inertia)
	)
	payload["approach_boundary_rad"] = upper if rate > 0.0 else lower
	payload["claim_boundary"] = CLAIM_BOUNDARY
	payload["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	return {"ok": true, "contract": FrozenValueScript.snapshot(payload)}


static func analyze(contract: Dictionary, samples: Array) -> Dictionary:
	var check := _verify_contract(contract)
	if not bool(check.get("ok", false)):
		return check
	if samples.size() != int(contract["sample_ticks"]):
		return _failure("HARD_LIMIT_SAMPLE_COUNT_MISMATCH")
	var reflected_inertia := float(contract["analytic_reflected_inertia_kg_m2"])
	var direction := signf(float(contract["initial_relative_rate_rad_s"]))
	var boundary := float(contract["approach_boundary_rad"])
	var max_directional_angle := 0.0
	var max_reaction_impulse := 0.0
	var reaction_tick := -1
	var max_momentum_abs := 0.0
	var max_anchor_error := 0.0
	var max_axis_error := 0.0
	var max_swing := 0.0
	var max_off_axis := 0.0
	var final_angle := 0.0
	var final_rate := 0.0
	var every_observation_valid := true
	for index in samples.size():
		var value: Variant = samples[index]
		if not value is Dictionary:
			return _failure("HARD_LIMIT_SAMPLE_INVALID")
		var sample: Dictionary = value
		if int(sample.get("tick", -1)) != index:
			return _failure("HARD_LIMIT_TICK_MISMATCH")
		for field in [
			"angle_before_rad",
			"angle_after_rad",
			"relative_rate_before_rad_s",
			"relative_rate_after_rad_s",
			"parent_rate_after_rad_s",
			"child_rate_after_rad_s",
			"parent_axis_inertia_kg_m2",
			"child_axis_inertia_kg_m2",
			"active_torque_nm",
			"passive_torque_nm",
			"anchor_error_m",
			"axis_error_rad",
			"swing_residual_rad",
			"off_axis_rate_rad_s",
		]:
			if not _finite_number(sample.get(field)):
				return _failure("HARD_LIMIT_SAMPLE_NONFINITE", {"sample": index, "field": field})
		if (
			float(sample["active_torque_nm"]) != 0.0
			or float(sample["passive_torque_nm"]) != 0.0
			or int(sample.get("command_count", -1)) != 0
		):
			return _failure("HARD_LIMIT_HIDDEN_TORQUE_OR_COMMAND")
		var angle_after := float(sample["angle_after_rad"])
		var rate_before := float(sample["relative_rate_before_rad_s"])
		var rate_after := float(sample["relative_rate_after_rad_s"])
		var reaction_impulse := reflected_inertia * (rate_after - rate_before)
		if absf(reaction_impulse) > absf(max_reaction_impulse):
			max_reaction_impulse = reaction_impulse
			reaction_tick = index
		max_directional_angle = maxf(max_directional_angle, direction * angle_after)
		final_angle = angle_after
		final_rate = rate_after
		var momentum := (
			float(sample["parent_axis_inertia_kg_m2"]) * float(sample["parent_rate_after_rad_s"])
			+ float(sample["child_axis_inertia_kg_m2"]) * float(sample["child_rate_after_rad_s"])
		)
		max_momentum_abs = maxf(max_momentum_abs, absf(momentum))
		max_anchor_error = maxf(max_anchor_error, float(sample["anchor_error_m"]))
		max_axis_error = maxf(max_axis_error, float(sample["axis_error_rad"]))
		max_swing = maxf(max_swing, float(sample["swing_residual_rad"]))
		max_off_axis = maxf(max_off_axis, float(sample["off_axis_rate_rad_s"]))
		every_observation_valid = (
			bool(sample.get("joint_observation_valid", false)) and every_observation_valid
		)
	var acceptance_failures: Array[String] = []
	if not every_observation_valid:
		acceptance_failures.append("JOINT_OBSERVATION_INVALID")
	if max_momentum_abs > 1.0e-4:
		acceptance_failures.append("TOTAL_ANGULAR_MOMENTUM_DRIFT_EXCEEDED")
	if (
		max_anchor_error > 5.0e-3
		or max_axis_error > 2.0e-2
		or max_swing > 2.0e-2
		or max_off_axis > 5.0e-2
	):
		acceptance_failures.append("JOINT_GEOMETRY_ENVELOPE_EXCEEDED")
	if bool(contract["limit_enabled"]):
		if max_directional_angle > absf(boundary) + 0.03:
			acceptance_failures.append("HARD_LIMIT_PENETRATION_EXCEEDED")
		if absf(max_reaction_impulse) < 0.005 or reaction_tick < 0:
			acceptance_failures.append("HARD_LIMIT_REACTION_NOT_DETECTED")
		if direction * final_rate > 0.1:
			acceptance_failures.append("HARD_LIMIT_DID_NOT_ARREST_APPROACH")
	else:
		if max_directional_angle < absf(boundary) + 0.2:
			acceptance_failures.append("LIMIT_DISABLED_CONTROL_DID_NOT_CROSS_BOUNDARY")
		if absf(max_reaction_impulse) > 1.0e-4:
			acceptance_failures.append("LIMIT_DISABLED_CONTROL_HAS_REACTION")
	var result := {
		"schema_version": RESULT_SCHEMA_VERSION,
		"trial_id": contract["trial_id"],
		"configuration_sha256": contract["configuration_sha256"],
		"limit_enabled": contract["limit_enabled"],
		"approach_boundary_rad": boundary,
		"max_directional_angle_rad": max_directional_angle,
		"final_angle_rad": final_angle,
		"final_rate_rad_s": final_rate,
		"max_constraint_reaction_impulse_n_m_s": max_reaction_impulse,
		"constraint_reaction_tick": reaction_tick,
		"reaction_classification":
		"hard_limit_constraint_reaction" if bool(contract["limit_enabled"]) else "none",
		"reaction_estimator": "relative_momentum_balance_v1",
		"active_torque_nm": 0.0,
		"passive_torque_nm": 0.0,
		"command_count": 0,
		"max_total_axis_angular_momentum_abs_n_m_s": max_momentum_abs,
		"accepted": acceptance_failures.is_empty(),
		"acceptance_failures": acceptance_failures,
		"claim_boundary": contract["claim_boundary"],
	}
	result["result_sha256"] = CanonicalJsonScript.sha256(result)
	return {"ok": true, "result": FrozenValueScript.snapshot(result)}


static func _verify_contract(contract: Dictionary) -> Dictionary:
	var configuration: Dictionary = {}
	for field in REQUIRED_FIELDS:
		if not contract.has(field):
			return _failure("HARD_LIMIT_CONTRACT_INCOMPLETE")
		configuration[field] = contract[field]
	var rebuilt := build(configuration)
	if not bool(rebuilt.get("ok", false)):
		return _failure("HARD_LIMIT_CONTRACT_INVALID", rebuilt)
	if (
		CanonicalJsonScript.stringify(rebuilt["contract"])
		!= CanonicalJsonScript.stringify(contract)
	):
		return _failure("HARD_LIMIT_CONTRACT_DIGEST_MISMATCH")
	return {"ok": true}


static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and (value as Array).size() == 3:
		var raw: Array = value
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3(INF, INF, INF)


static func _positive_vector(value: Vector3) -> bool:
	return value.is_finite() and value.x > 0.0 and value.y > 0.0 and value.z > 0.0


static func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _positive_integer(value: Variant) -> int:
	if value is int and int(value) > 0:
		return int(value)
	if value is float and is_finite(value) and value > 0.0 and value == floor(value):
		return int(value)
	return -1


static func _stable_id(value: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^[A-Za-z][A-Za-z0-9._-]{0,159}$")
	return expression.search(value) != null


static func _failure(code: String, details: Variant = null) -> Dictionary:
	return {"ok": false, "failure_code": code, "details": details}
