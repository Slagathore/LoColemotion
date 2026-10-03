extends SceneTree
# gdlint: disable=max-line-length

## BR9.1 specific reserve, friction, contact-set, timing, and input refusal.

const ControllerScript := preload("res://scripts/lab/mechanics/brace_controller.gd")

const CONFIGURATION := {
	"schema_version": "existing_contact_brace_configuration_v1",
	"angular_momentum_gain_s_inv": 12.0,
	"pitch_rate_gain_nm_s_rad": 0.0,
	"reserve_fraction": 0.20,
	"max_normal_load_rate_n_s": 120.0,
	"max_tangent_load_rate_n_s": 120.0,
	"stable_angular_momentum_abs_kg_m2_s": 0.01,
	"stable_pitch_error_abs_rad": 0.02,
	"stable_pitch_rate_abs_rad_s": 0.02,
	"stable_dwell_ticks": 3,
	"feasibility_tolerance": 1.0e-8,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR9.1 brace feasibility ===")
	var low_capacity := _request()
	low_capacity["maximum_normal_n"] = 22.0
	_assert_failure(
		low_capacity,
		"BRACE_ACTUATOR_RESERVE_INFEASIBLE",
		"insufficient reserved normal capacity fails specifically"
	)
	var low_friction := _request()
	low_friction["friction_coefficient"] = 0.40
	low_friction["desired_force_x_n"] = 20.0
	_assert_failure(
		low_friction,
		"BRACE_FRICTION_INFEASIBLE",
		"reserved Coulomb-cone overflow fails specifically"
	)
	var missing_contact := _request()
	missing_contact["right_bearing"] = false
	_assert_failure(
		missing_contact,
		"EXISTING_CONTACT_SET_INCOMPLETE",
		"an absent pre-existing contact cannot be silently replaced"
	)
	var too_late := _request()
	too_late["detector_state"] = "REACTION_TOO_LATE"
	_assert_failure(
		too_late,
		"REACTION_TOO_LATE",
		"the BR8 delayed negative control cannot be converted into a brace command"
	)
	var inactive := _request()
	inactive["detector_state"] = "STAND"
	_assert_failure(
		inactive, "BRACE_STATE_NOT_ACTIVE", "a non-BRACE observation cannot activate the controller"
	)
	var nonfinite := _request()
	nonfinite["angular_momentum_z_kg_m2_s"] = NAN
	_assert_failure(
		nonfinite,
		"BRACE_REQUEST_NONFINITE:angular_momentum_z_kg_m2_s",
		"nonfinite observed momentum fails closed"
	)
	var forged_field := _request()
	forged_field["root_rescue_force_n"] = 1000.0
	_assert_failure(
		forged_field,
		"BRACE_REQUEST_FIELD_SET_MISMATCH",
		"a caller cannot add a root-rescue channel to the strict request"
	)
	var controller = ControllerScript.new()
	var setup: Dictionary = controller.configure(CONFIGURATION, 20.0, 20.0)
	var first: Dictionary = controller.update(_request())
	var replay: Dictionary = controller.update(_request())
	_check(
		(
			bool(setup.get("ok", false))
			and bool(first.get("ok", false))
			and not bool(replay.get("ok", true))
			and String(replay.get("failure_code", "")) == "BRACE_TICK_NOT_STRICTLY_INCREASING"
		),
		"ticks are monotonic and a replayed command request is refused"
	)
	var invalid_configuration := CONFIGURATION.duplicate(true)
	invalid_configuration["reserve_fraction"] = 1.0
	var invalid_result := ControllerScript.validate_configuration(invalid_configuration)
	_check(
		(
			not bool(invalid_result.get("ok", true))
			and (
				String(invalid_result.get("failure_code", ""))
				== "BRACE_CONFIGURATION_BOUNDS_INVALID"
			)
		),
		"configuration cannot reserve away the entire physical envelope"
	)
	_finish()


func _assert_failure(request: Dictionary, code: String, label: String) -> void:
	var controller = ControllerScript.new()
	var setup: Dictionary = controller.configure(CONFIGURATION, 20.0, 20.0)
	var result: Dictionary = controller.update(request)
	_check(
		(
			bool(setup.get("ok", false))
			and not bool(result.get("ok", true))
			and String(result.get("failure_code", "")) == code
		),
		label
	)
	if bool(result.get("ok", true)) or String(result.get("failure_code", "")) != code:
		printerr("  expected=", code, " actual=", result)


func _request() -> Dictionary:
	return {
		"schema_version": "existing_contact_brace_request_v1",
		"tick": 0,
		"detector_state": "BRACE",
		"angular_momentum_z_kg_m2_s": 0.20,
		"pitch_error_rad": 0.0,
		"pitch_rate_rad_s": 0.0,
		"desired_force_x_n": 0.0,
		"desired_force_y_n": 40.0,
		"left_support_x_m": -0.30,
		"right_support_x_m": 0.30,
		"left_bearing": true,
		"right_bearing": true,
		"friction_coefficient": 0.8,
		"minimum_normal_n": 0.0,
		"maximum_normal_n": 50.0,
		"dt_s": 1.0 / 60.0,
	}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
