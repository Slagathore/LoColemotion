extends SceneTree
# gdlint: disable=max-line-length

## BR9.0 exact arrest-wrench, load-rate, mirroring, and STABILIZE handoff truth.

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
	print("=== Experimental BR9.0 existing-contact brace arithmetic ===")
	var validated := ControllerScript.validate_configuration(CONFIGURATION)
	_check(
		(
			bool(validated.get("ok", false))
			and (validated["configuration"] as Dictionary).is_read_only()
		),
		"strict brace configuration seals as an immutable digest-bound value"
	)
	var positive = _controller()
	var negative = _controller()
	_check(
		bool(positive["setup"].get("ok", false)) and bool(negative["setup"].get("ok", false)),
		"mirrored controllers start from the same balanced non-measurement command"
	)
	var positive_result: Dictionary = positive["controller"].update(_request(0, 0.5, 0.0))
	var negative_result: Dictionary = negative["controller"].update(_request(0, -0.5, 0.0))
	_check(
		bool(positive_result.get("ok", false)) and bool(negative_result.get("ok", false)),
		"both signed momentum requests remain inside the reserved contact envelope"
	)
	if not bool(positive_result.get("ok", false)) or not bool(negative_result.get("ok", false)):
		printerr("  positive=", positive_result, " negative=", negative_result)
		_finish()
		return
	var p: Dictionary = positive_result["command"]
	var n: Dictionary = negative_result["command"]
	_check(
		(
			is_equal_approx(float(p["desired_arrest_moment_z_nm"]), -6.0)
			and is_equal_approx(float(n["desired_arrest_moment_z_nm"]), 6.0)
			and is_equal_approx(float(p["target_allocation"]["left"]["normal_force_n"]), 30.0)
			and is_equal_approx(float(p["target_allocation"]["right"]["normal_force_n"]), 10.0)
			and is_equal_approx(float(n["target_allocation"]["left"]["normal_force_n"]), 10.0)
			and is_equal_approx(float(n["target_allocation"]["right"]["normal_force_n"]), 30.0)
		),
		"arrest moment opposes signed momentum and mirrors the target redistribution exactly"
	)
	_check(
		(
			bool(p["rate_limited"])
			and bool(n["rate_limited"])
			and is_equal_approx(float(p["left"]["normal_force_n"]), 22.0)
			and is_equal_approx(float(p["right"]["normal_force_n"]), 18.0)
			and is_equal_approx(float(n["left"]["normal_force_n"]), 18.0)
			and is_equal_approx(float(n["right"]["normal_force_n"]), 22.0)
			and is_equal_approx(float(p["normal_load_rate_n_s"]), 120.0)
			and is_equal_approx(float(n["normal_load_rate_n_s"]), 120.0)
		),
		"first-tick redistribution respects the exact 120 N/s normal-load-rate ceiling"
	)
	_check(
		(
			is_equal_approx(float(p["achieved_command_moment_z_nm"]), -1.2)
			and is_equal_approx(float(n["achieved_command_moment_z_nm"]), 1.2)
			and is_equal_approx(float(p["moment_residual_z_nm"]), 4.8)
			and is_equal_approx(float(n["moment_residual_z_nm"]), -4.8)
		),
		"rate-limited achieved moment and signed desired/achieved residual remain explicit"
	)
	_check(
		(
			float(p["minimum_remaining_normal_reserve_n"]) >= 10.0 - 1.0e-8
			and bool(p["existing_contacts_only"])
			and bool(p["per_contact_values_are_commands_not_measurements"])
			and not bool(p["root_intervention_requested"])
			and not bool(p["foot_pin_requested"])
			and not bool(p["new_contact_requested"])
			and not bool(p["automatic_creature_guidance_requested"])
		),
		"reserve and causal boundaries remain machine-readable"
	)

	var stable = _controller()
	var state_sequence: Array[String] = []
	for tick in 3:
		var result: Dictionary = stable["controller"].update(_request(tick, 0.0, 0.0))
		if not bool(result.get("ok", false)):
			printerr("  stable_failure=", result)
			state_sequence.append("ERROR")
		else:
			state_sequence.append(String(result["command"]["handoff_state"]))
	_check(
		state_sequence == ["BRACE", "BRACE", "STABILIZE"],
		"STABILIZE handoff occurs only after the complete three-tick stable dwell"
	)
	var chatter = _controller()
	var c0: Dictionary = chatter["controller"].update(_request(0, 0.0, 0.0))
	var c1: Dictionary = chatter["controller"].update(_request(1, 0.02, 0.0))
	var c2: Dictionary = chatter["controller"].update(_request(2, 0.0, 0.0))
	var c3: Dictionary = chatter["controller"].update(_request(3, 0.0, 0.0))
	_check(
		(
			String(c0["command"]["handoff_state"]) == "BRACE"
			and String(c1["command"]["handoff_state"]) == "BRACE"
			and String(c2["command"]["handoff_state"]) == "BRACE"
			and String(c3["command"]["handoff_state"]) == "BRACE"
		),
		"one unsafe sample resets the dwell and prevents a premature handoff"
	)
	_finish()


func _controller() -> Dictionary:
	var controller = ControllerScript.new()
	return {
		"controller": controller,
		"setup": controller.configure(CONFIGURATION, 20.0, 20.0),
	}


func _request(tick: int, angular_momentum: float, pitch_rate: float) -> Dictionary:
	return {
		"schema_version": "existing_contact_brace_request_v1",
		"tick": tick,
		"detector_state": "BRACE",
		"angular_momentum_z_kg_m2_s": angular_momentum,
		"pitch_error_rad": 0.0,
		"pitch_rate_rad_s": pitch_rate,
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
