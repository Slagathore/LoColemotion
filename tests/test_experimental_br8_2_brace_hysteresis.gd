extends SceneTree

## BR8.2 immediate escalation, hysteretic release, and reasoned transitions.

const DetectorScript := preload("res://scripts/lab/mechanics/brace_detector.gd")
const SupervisorScript := preload("res://scripts/lab/mechanics/brace_supervisor.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR8.2 brace supervisor hysteresis ===")
	var supervisor = SupervisorScript.new(3)
	var stable := supervisor.update(0, _evidence(_request(0, 0.0, 0.0)))
	var precarious := supervisor.update(1, _evidence(_request(1, 0.42, 0.0)))
	var brace := supervisor.update(2, _evidence(_request(2, 0.48, 0.0)))
	_check(
		(
			String(stable["state"]) == "STAND"
			and String(precarious["state"]) == "PRECARIOUS"
			and String(brace["state"]) == "BRACE"
		),
		"STAND to PRECARIOUS to BRACE escalation is immediate"
	)
	_check(
		(
			String(precarious["transition"]["from_state"]) == "STAND"
			and String(precarious["transition"]["to_state"]) == "PRECARIOUS"
			and String(precarious["transition"]["reason"]) == "SUPPORT_MARGIN_PRECARIOUS"
			and String(precarious["transition"]["evidence_sha256"]).begins_with("sha256:")
		),
		"PRECARIOUS transition retains decomposed evidence and its digest"
	)
	_check(
		(
			String(brace["transition"]["from_state"]) == "PRECARIOUS"
			and String(brace["transition"]["to_state"]) == "BRACE"
			and String(brace["response"]) == "DECLARE_BRACE_REQUIRED_NO_ACTUATION"
		),
		"BRACE transition retains its reason without applying a brace"
	)

	var unsafe_release := supervisor.update(3, _evidence(_request(3, 0.35, 0.0)))
	_check(
		(
			String(unsafe_release["state"]) == "BRACE"
			and int(unsafe_release["release_dwell_progress"]) == 0
		),
		"margin below the release threshold cannot start de-escalation"
	)
	var release_1 := supervisor.update(4, _evidence(_request(4, 0.0, 0.0)))
	var release_2 := supervisor.update(5, _evidence(_request(5, 0.0, 0.0)))
	var release_3 := supervisor.update(6, _evidence(_request(6, 0.0, 0.0)))
	_check(
		(
			String(release_1["state"]) == "BRACE"
			and String(release_2["state"]) == "BRACE"
			and String(release_3["state"]) == "PRECARIOUS"
		),
		"three safe samples release BRACE by only one state"
	)
	var release_4 := supervisor.update(7, _evidence(_request(7, 0.0, 0.0)))
	var release_5 := supervisor.update(8, _evidence(_request(8, 0.0, 0.0)))
	var release_6 := supervisor.update(9, _evidence(_request(9, 0.0, 0.0)))
	_check(
		(
			String(release_4["state"]) == "PRECARIOUS"
			and String(release_5["state"]) == "PRECARIOUS"
			and String(release_6["state"]) == "STAND"
		),
		"a second complete dwell is required to return to STAND"
	)
	_check(
		(
			not bool(brace["automatic_force_application"])
			and not bool(brace["automatic_step_command"])
			and not bool(brace["automatic_creature_guidance"])
		),
		"supervisor has no force, step, or creature-guidance authority"
	)

	var delayed_supervisor = SupervisorScript.new(2)
	var delayed_request := _request(0, 0.45, 0.50)
	var delayed := delayed_supervisor.update(0, _evidence(delayed_request))
	_check(
		(
			String(delayed["state"]) == "BRACE"
			and String(delayed["transition"]["reason"]) == "REACTION_TOO_LATE"
			and String(delayed["response"]) == "DECLARE_REACTION_TOO_LATE_STOP"
		),
		"delayed negative control is explicitly REACTION_TOO_LATE"
	)
	_check(
		not bool(delayed_supervisor.update(0, _evidence(delayed_request)).get("ok", true)),
		"duplicate or nonmonotonic supervisor ticks fail closed"
	)
	_finish()


static func _request(tick: int, com_x_m: float, velocity_x_m_s: float) -> Dictionary:
	return {
		"schema_version": "brace_detection_request_v1",
		"tick": tick,
		"com_x_m": com_x_m,
		"com_velocity_x_m_s": velocity_x_m_s,
		"com_height_m": 0.8,
		"vertical_velocity_m_s": 0.0,
		"body_clearance_m": 0.0,
		"gravity_m_s2": 9.8,
		"support_min_x_m": -0.5,
		"support_max_x_m": 0.5,
		"bearing_support_count": 2,
		"brace_margin_m": 0.03,
		"precarious_margin_m": 0.12,
		"release_margin_m": 0.18,
		"reaction_time_s": 0.12,
		"safety_time_s": 0.03,
		"brace_trigger_time_s": 0.35,
		"precarious_trigger_time_s": 0.75,
		"airborne": false,
	}


static func _evidence(request: Dictionary) -> Dictionary:
	var result := DetectorScript.evaluate(request)
	assert(bool(result.get("ok", false)))
	return result["evidence"]


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
