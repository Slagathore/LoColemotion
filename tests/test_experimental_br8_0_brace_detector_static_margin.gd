extends SceneTree

## BR8.0 exact static-margin and impact-deadline detector oracles.

const DetectorScript := preload("res://scripts/lab/mechanics/brace_detector.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR8.0 brace detector static margin ===")
	var centered := _evidence(_request(0, 0.0, 0.0))
	_check(
		(
			String(centered["recommended_state"]) == "STAND"
			and absf(float(centered["static_margin_m"]) - 0.5) <= 1.0e-12
			and absf(float(centered["capture_margin_m"]) - 0.5) <= 1.0e-12
		),
		"centered stationary support has exact safe margins"
	)
	_check(
		(
			not bool(centered["time_to_boundary_available"])
			and not bool(centered["time_to_impact_available"])
			and bool(centered["reaction_viable"])
		),
		"stationary supported body does not manufacture a deadline"
	)

	var precarious := _evidence(_request(1, 0.42, 0.0))
	_check(
		(
			String(precarious["recommended_state"]) == "PRECARIOUS"
			and String(precarious["dominant_reason"]) == "SUPPORT_MARGIN_PRECARIOUS"
			and absf(float(precarious["static_margin_m"]) - 0.08) <= 1.0e-12
		),
		"positive near-edge COM enters PRECARIOUS at the declared static margin"
	)
	var mirrored := _evidence(_request(2, -0.42, 0.0))
	_check(
		(
			String(mirrored["recommended_state"]) == "PRECARIOUS"
			and absf(float(mirrored["static_margin_m"]) - 0.08) <= 1.0e-12
		),
		"negative near-edge COM mirrors the static-margin classification"
	)

	var brace := _evidence(_request(3, 0.48, 0.0))
	_check(
		(
			String(brace["recommended_state"]) == "BRACE"
			and String(brace["dominant_reason"]) == "STATIC_MARGIN_BRACE"
			and absf(float(brace["static_margin_m"]) - 0.02) <= 1.0e-12
		),
		"declared brace margin escalates before the COM crosses the support edge"
	)
	var exhausted := _evidence(_request(4, 0.55, 0.0))
	_check(
		(
			String(exhausted["recommended_state"]) == "BRACE"
			and String(exhausted["dominant_reason"]) == "STATIC_MARGIN_EXHAUSTED"
			and String(exhausted["static_loss_direction"]) == "right"
		),
		"outside support is classified with its exact loss direction"
	)

	var no_support_request := _request(5, 0.0, 0.0)
	no_support_request["bearing_support_count"] = 0
	var no_support := _evidence(no_support_request)
	_check(
		(
			String(no_support["recommended_state"]) == "BRACE"
			and String(no_support["dominant_reason"]) == "NO_BEARING_SUPPORT"
		),
		"zero bearing supports fails into BRACE without claiming an executed brace"
	)

	var airborne_request := _request(6, 0.0, 0.0)
	airborne_request["airborne"] = true
	airborne_request["body_clearance_m"] = 0.01
	airborne_request["vertical_velocity_m_s"] = -1.0
	var airborne := _evidence(airborne_request)
	_check(
		(
			bool(airborne["time_to_impact_available"])
			and not bool(airborne["reaction_viable"])
			and String(airborne["dominant_reason"]) == "REACTION_TOO_LATE"
		),
		"delayed airborne observation is classified REACTION_TOO_LATE"
	)
	_check(
		(
			not bool(airborne["automatic_force_application"])
			and not bool(airborne["automatic_creature_guidance"])
			and bool(airborne["planar_scaffold_observation_only"])
		),
		"detector evidence has no actuation or guidance authority"
	)

	var malformed := _request(7, 0.0, 0.0)
	malformed["release_margin_m"] = 0.10
	_check(
		(
			String(DetectorScript.evaluate(malformed).get("failure_code", ""))
			== "BRACE_DETECTOR_BOUNDS_INVALID"
		),
		"overlapping hysteresis margins fail closed"
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
