class_name LabExistingContactBraceController
extends RefCounted
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## BR9 existing-contact planar brace controller.
##
## A BR8 observation may request this controller, but it cannot apply anything
## directly. The controller computes one reserve-bounded two-contact wrench,
## rate-limits the commanded contact redistribution, and reports the exact
## desired/target/achieved residual. Per-contact values remain commands rather
## than measurements. A later force-to-joint map, command ledger, executor, and
## receipt sink own physical application.

const AllocatorScript := preload("res://scripts/lab/mechanics/planar_contact_allocator.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const CONFIGURATION_SCHEMA := "existing_contact_brace_configuration_v1"
const REQUEST_SCHEMA := "existing_contact_brace_request_v1"
const CONFIGURATION_FIELDS: Array[String] = [
	"schema_version",
	"angular_momentum_gain_s_inv",
	"pitch_rate_gain_nm_s_rad",
	"reserve_fraction",
	"max_normal_load_rate_n_s",
	"max_tangent_load_rate_n_s",
	"stable_angular_momentum_abs_kg_m2_s",
	"stable_pitch_error_abs_rad",
	"stable_pitch_rate_abs_rad_s",
	"stable_dwell_ticks",
	"feasibility_tolerance",
]
const REQUEST_FIELDS: Array[String] = [
	"schema_version",
	"tick",
	"detector_state",
	"angular_momentum_z_kg_m2_s",
	"pitch_error_rad",
	"pitch_rate_rad_s",
	"desired_force_x_n",
	"desired_force_y_n",
	"left_support_x_m",
	"right_support_x_m",
	"left_bearing",
	"right_bearing",
	"friction_coefficient",
	"minimum_normal_n",
	"maximum_normal_n",
	"dt_s",
]

var _configuration: Dictionary = {}
var _previous_left_normal_n := 0.0
var _previous_right_normal_n := 0.0
var _previous_left_tangent_n := 0.0
var _previous_right_tangent_n := 0.0
var _stable_dwell := 0
var _last_tick := -1


static func validate_configuration(configuration: Dictionary) -> Dictionary:
	if not _field_set_matches(configuration, CONFIGURATION_FIELDS):
		return _failure("BRACE_CONFIGURATION_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != CONFIGURATION_SCHEMA:
		return _failure("BRACE_CONFIGURATION_SCHEMA_UNSUPPORTED")
	for field in [
		"angular_momentum_gain_s_inv",
		"pitch_rate_gain_nm_s_rad",
		"reserve_fraction",
		"max_normal_load_rate_n_s",
		"max_tangent_load_rate_n_s",
		"stable_angular_momentum_abs_kg_m2_s",
		"stable_pitch_error_abs_rad",
		"stable_pitch_rate_abs_rad_s",
		"feasibility_tolerance",
	]:
		if not _finite_number(configuration.get(field)):
			return _failure("BRACE_CONFIGURATION_NONFINITE:%s" % field)
	if (
		float(configuration["angular_momentum_gain_s_inv"]) <= 0.0
		or float(configuration["pitch_rate_gain_nm_s_rad"]) < 0.0
		or float(configuration["reserve_fraction"]) <= 0.0
		or float(configuration["reserve_fraction"]) >= 1.0
		or float(configuration["max_normal_load_rate_n_s"]) <= 0.0
		or float(configuration["max_tangent_load_rate_n_s"]) <= 0.0
		or float(configuration["stable_angular_momentum_abs_kg_m2_s"]) < 0.0
		or float(configuration["stable_pitch_error_abs_rad"]) < 0.0
		or float(configuration["stable_pitch_rate_abs_rad_s"]) < 0.0
		or float(configuration["feasibility_tolerance"]) <= 0.0
	):
		return _failure("BRACE_CONFIGURATION_BOUNDS_INVALID")
	if (
		not configuration.get("stable_dwell_ticks") is int
		or int(configuration["stable_dwell_ticks"]) <= 0
	):
		return _failure("BRACE_CONFIGURATION_DWELL_INVALID")
	var payload := configuration.duplicate(true)
	payload["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	payload["claim_boundary"] = (
		"Existing-contact planar brace requests only: two already-bearing contacts, "
		+ "reserve-aware unilateral and friction feasibility, bounded load-rate "
		+ "redistribution, explicit desired/achieved residual, and a stable-dwell "
		+ "STABILIZE handoff. Contact shares are commands, not measurements. This "
		+ "controller applies no force, torque, root rescue, foot pin, new contact, "
		+ "creature edit, or guidance by itself."
	)
	return {"ok": true, "configuration": FrozenValueScript.snapshot(payload)}


func configure(
	configuration: Dictionary,
	initial_left_normal_n: float,
	initial_right_normal_n: float,
	initial_left_tangent_n := 0.0,
	initial_right_tangent_n := 0.0
) -> Dictionary:
	var validated := validate_configuration(configuration)
	if not bool(validated.get("ok", false)):
		return validated
	for value in [
		initial_left_normal_n,
		initial_right_normal_n,
		initial_left_tangent_n,
		initial_right_tangent_n,
	]:
		if not is_finite(float(value)):
			return _failure("BRACE_INITIAL_COMMAND_NONFINITE")
	if initial_left_normal_n < 0.0 or initial_right_normal_n < 0.0:
		return _failure("BRACE_INITIAL_NORMAL_NEGATIVE")
	_configuration = validated["configuration"]
	_previous_left_normal_n = initial_left_normal_n
	_previous_right_normal_n = initial_right_normal_n
	_previous_left_tangent_n = initial_left_tangent_n
	_previous_right_tangent_n = initial_right_tangent_n
	_stable_dwell = 0
	_last_tick = -1
	return {
		"ok": true,
		"configuration": _configuration,
		"initial_commands_are_measurements": false,
	}


func update(request: Dictionary) -> Dictionary:
	if _configuration.is_empty():
		return _failure("BRACE_CONTROLLER_NOT_CONFIGURED")
	var request_valid := _validate_request(request)
	if not bool(request_valid.get("ok", false)):
		return request_valid
	var tick := int(request["tick"])
	if tick <= _last_tick:
		return _failure("BRACE_TICK_NOT_STRICTLY_INCREASING")
	var detector_state := String(request["detector_state"])
	if detector_state == "REACTION_TOO_LATE":
		return _failure("REACTION_TOO_LATE")
	if detector_state != "BRACE":
		return _failure("BRACE_STATE_NOT_ACTIVE")
	if not bool(request["left_bearing"]) or not bool(request["right_bearing"]):
		return _failure("EXISTING_CONTACT_SET_INCOMPLETE")
	var reserve_fraction := float(_configuration["reserve_fraction"])
	var reserved_maximum_normal := float(request["maximum_normal_n"]) * (1.0 - reserve_fraction)
	var reserved_friction := float(request["friction_coefficient"]) * (1.0 - reserve_fraction)
	if reserved_maximum_normal <= float(request["minimum_normal_n"]) or reserved_friction <= 0.0:
		return _failure("BRACE_RESERVE_ERASES_CAPACITY")
	var desired_moment := (
		(
			-float(_configuration["angular_momentum_gain_s_inv"])
			* float(request["angular_momentum_z_kg_m2_s"])
		)
		- float(_configuration["pitch_rate_gain_nm_s_rad"]) * float(request["pitch_rate_rad_s"])
	)
	var allocation_result := (
		AllocatorScript
		. allocate(
			{
				"schema_version": "planar_contact_allocation_request_v1",
				"tick": tick,
				"desired_force_x_n": float(request["desired_force_x_n"]),
				"desired_force_y_n": float(request["desired_force_y_n"]),
				"desired_moment_z_nm": desired_moment,
				"left_support_x_m": float(request["left_support_x_m"]),
				"right_support_x_m": float(request["right_support_x_m"]),
				"left_bearing": true,
				"right_bearing": true,
				"friction_coefficient": reserved_friction,
				"minimum_normal_n": float(request["minimum_normal_n"]),
				"maximum_normal_n": reserved_maximum_normal,
				"feasibility_tolerance": float(_configuration["feasibility_tolerance"]),
			}
		)
	)
	if not bool(allocation_result.get("ok", false)):
		return _failure(
			"BRACE_ALLOCATOR_REFUSED_REQUEST",
			{"allocator_failure_code": allocation_result.get("failure_code", "")}
		)
	var target: Dictionary = allocation_result["allocation"]
	if not bool(target["feasible"]):
		var reasons: Array = target["infeasibility_reasons"]
		var code := _specific_infeasibility(reasons)
		return _failure(code, {"infeasibility_reasons": reasons})
	var dt := float(request["dt_s"])
	var normal_step := float(_configuration["max_normal_load_rate_n_s"]) * dt
	var tangent_step := float(_configuration["max_tangent_load_rate_n_s"]) * dt
	var left_normal := _rate_limit(
		_previous_left_normal_n, float(target["left"]["normal_force_n"]), normal_step
	)
	var right_normal := _rate_limit(
		_previous_right_normal_n, float(target["right"]["normal_force_n"]), normal_step
	)
	var left_tangent := _rate_limit(
		_previous_left_tangent_n, float(target["left"]["tangent_force_n"]), tangent_step
	)
	var right_tangent := _rate_limit(
		_previous_right_tangent_n, float(target["right"]["tangent_force_n"]), tangent_step
	)
	var achieved_force_x := left_tangent + right_tangent
	var achieved_force_y := left_normal + right_normal
	var achieved_moment := (
		float(request["left_support_x_m"]) * left_normal
		+ float(request["right_support_x_m"]) * right_normal
	)
	var residual_force := Vector2(
		achieved_force_x - float(request["desired_force_x_n"]),
		achieved_force_y - float(request["desired_force_y_n"])
	)
	var residual_moment := achieved_moment - desired_moment
	var normal_rate := (
		maxf(
			absf(left_normal - _previous_left_normal_n),
			absf(right_normal - _previous_right_normal_n)
		)
		/ dt
	)
	var tangent_rate := (
		maxf(
			absf(left_tangent - _previous_left_tangent_n),
			absf(right_tangent - _previous_right_tangent_n)
		)
		/ dt
	)
	var rate_limited := (
		not is_equal_approx(left_normal, float(target["left"]["normal_force_n"]))
		or not is_equal_approx(right_normal, float(target["right"]["normal_force_n"]))
		or not is_equal_approx(left_tangent, float(target["left"]["tangent_force_n"]))
		or not is_equal_approx(right_tangent, float(target["right"]["tangent_force_n"]))
	)
	var stable := (
		(
			absf(float(request["angular_momentum_z_kg_m2_s"]))
			<= float(_configuration["stable_angular_momentum_abs_kg_m2_s"])
		)
		and (
			absf(float(request["pitch_error_rad"]))
			<= float(_configuration["stable_pitch_error_abs_rad"])
		)
		and (
			absf(float(request["pitch_rate_rad_s"]))
			<= float(_configuration["stable_pitch_rate_abs_rad_s"])
		)
	)
	_stable_dwell = _stable_dwell + 1 if stable else 0
	var handoff_state := (
		"STABILIZE" if _stable_dwell >= int(_configuration["stable_dwell_ticks"]) else "BRACE"
	)
	_previous_left_normal_n = left_normal
	_previous_right_normal_n = right_normal
	_previous_left_tangent_n = left_tangent
	_previous_right_tangent_n = right_tangent
	_last_tick = tick
	return {
		"ok": true,
		"command":
		(
			FrozenValueScript
			. snapshot(
				{
					"schema_version": "existing_contact_brace_command_v1",
					"tick": tick,
					"source_request_sha256": CanonicalJsonScript.sha256(request),
					"detector_state": detector_state,
					"desired_force_world_n":
					[float(request["desired_force_x_n"]), float(request["desired_force_y_n"])],
					"desired_arrest_moment_z_nm": desired_moment,
					"target_allocation": target,
					"achieved_command_force_world_n": [achieved_force_x, achieved_force_y],
					"achieved_command_moment_z_nm": achieved_moment,
					"force_residual_n": [residual_force.x, residual_force.y],
					"moment_residual_z_nm": residual_moment,
					"left":
					{
						"normal_force_n": left_normal,
						"tangent_force_n": left_tangent,
					},
					"right":
					{
						"normal_force_n": right_normal,
						"tangent_force_n": right_tangent,
					},
					"normal_load_rate_n_s": normal_rate,
					"tangent_load_rate_n_s": tangent_rate,
					"rate_limited": rate_limited,
					"stable_dwell_ticks": _stable_dwell,
					"handoff_state": handoff_state,
					"reserved_maximum_normal_n": reserved_maximum_normal,
					"reserved_friction_coefficient": reserved_friction,
					"minimum_remaining_normal_reserve_n":
					minf(
						reserved_maximum_normal - float(target["left"]["normal_force_n"]),
						reserved_maximum_normal - float(target["right"]["normal_force_n"])
					),
					"existing_contacts_only": true,
					"per_contact_values_are_commands_not_measurements": true,
					"root_intervention_requested": false,
					"foot_pin_requested": false,
					"new_contact_requested": false,
					"automatic_creature_guidance_requested": false,
				}
			)
		),
	}


func _validate_request(request: Dictionary) -> Dictionary:
	if not _field_set_matches(request, REQUEST_FIELDS):
		return _failure("BRACE_REQUEST_FIELD_SET_MISMATCH")
	if String(request.get("schema_version", "")) != REQUEST_SCHEMA:
		return _failure("BRACE_REQUEST_SCHEMA_UNSUPPORTED")
	if not request.get("tick") is int or int(request["tick"]) < 0:
		return _failure("BRACE_REQUEST_TICK_INVALID")
	if typeof(request.get("detector_state")) != TYPE_STRING:
		return _failure("BRACE_REQUEST_DETECTOR_STATE_INVALID")
	for field in [
		"angular_momentum_z_kg_m2_s",
		"pitch_error_rad",
		"pitch_rate_rad_s",
		"desired_force_x_n",
		"desired_force_y_n",
		"left_support_x_m",
		"right_support_x_m",
		"friction_coefficient",
		"minimum_normal_n",
		"maximum_normal_n",
		"dt_s",
	]:
		if not _finite_number(request.get(field)):
			return _failure("BRACE_REQUEST_NONFINITE:%s" % field)
	for field in ["left_bearing", "right_bearing"]:
		if typeof(request.get(field)) != TYPE_BOOL:
			return _failure("BRACE_REQUEST_CONTACT_STATE_INVALID:%s" % field)
	if (
		float(request["left_support_x_m"]) >= float(request["right_support_x_m"])
		or float(request["friction_coefficient"]) <= 0.0
		or float(request["minimum_normal_n"]) < 0.0
		or float(request["maximum_normal_n"]) <= float(request["minimum_normal_n"])
		or float(request["dt_s"]) <= 0.0
	):
		return _failure("BRACE_REQUEST_BOUNDS_INVALID")
	return {"ok": true}


static func _specific_infeasibility(reasons: Array) -> String:
	for reason_value in reasons:
		if String(reason_value).contains("FRICTION_CONE"):
			return "BRACE_FRICTION_INFEASIBLE"
	for reason_value in reasons:
		var reason := String(reason_value)
		if reason.contains("NORMAL_ABOVE_MAXIMUM") or reason.contains("NORMAL_BELOW_MINIMUM"):
			return "BRACE_ACTUATOR_RESERVE_INFEASIBLE"
	return "BRACE_CONTACT_WRENCH_INFEASIBLE"


static func _rate_limit(previous: float, target: float, maximum_delta: float) -> float:
	return clampf(target, previous - maximum_delta, previous + maximum_delta)


static func _field_set_matches(value: Dictionary, fields: Array[String]) -> bool:
	var keys: Array = value.keys()
	keys.sort()
	var expected: Array = fields.duplicate()
	expected.sort()
	return keys == expected


static func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _failure(code: String, details: Variant = null) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"details": details,
	}
