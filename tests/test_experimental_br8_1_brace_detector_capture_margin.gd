extends SceneTree

## BR8.1 linear capture-margin and time-to-boundary detection oracles.

const DetectorScript := preload("res://scripts/lab/mechanics/brace_detector.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR8.1 brace detector capture margin ===")
	var slow := _evidence(_request(0, 0.0, 0.20))
	var expected_capture := 0.20 / sqrt(9.8 / 0.8)
	_check(
		(
			absf(float(slow["capture_point_x_m"]) - expected_capture) <= 1.0e-12
			and absf(float(slow["time_to_boundary_s"]) - 2.5) <= 1.0e-12
			and String(slow["recommended_state"]) == "STAND"
		),
		"slow motion has exact capture point and boundary time while remaining STAND"
	)

	var warning := _evidence(_request(1, 0.0, 1.40))
	_check(
		(
			String(warning["recommended_state"]) == "PRECARIOUS"
			and String(warning["dominant_reason"]) == "SUPPORT_MARGIN_PRECARIOUS"
			and float(warning["capture_margin_m"]) > 0.03
		),
		"capture margin enters PRECARIOUS before static support is endangered"
	)

	var brace := _evidence(_request(2, 0.0, 1.90))
	_check(
		(
			String(brace["recommended_state"]) == "BRACE"
			and String(brace["dominant_reason"]) == "CAPTURE_MARGIN_BRACE"
			and float(brace["static_margin_m"]) == 0.5
			and float(brace["capture_margin_m"]) <= 0.03
		),
		"fast impulse state reaches BRACE through capture evidence while COM remains centered"
	)
	var mirrored := _evidence(_request(3, 0.0, -1.90))
	_check(
		(
			String(mirrored["recommended_state"]) == "BRACE"
			and String(mirrored["capture_loss_direction"]) == "left"
			and (
				absf(float(mirrored["capture_margin_m"]) - float(brace["capture_margin_m"]))
				<= 1.0e-12
			)
		),
		"equal negative velocity mirrors capture urgency and loss direction"
	)

	var deadline_brace := _evidence(_request(4, 0.30, 0.59))
	_check(
		(
			String(deadline_brace["recommended_state"]) == "BRACE"
			and String(deadline_brace["dominant_reason"]) == "BOUNDARY_DEADLINE_BRACE"
			and float(deadline_brace["time_to_boundary_s"]) > 0.15
		),
		"time deadline can demand BRACE while reaction remains viable"
	)
	var delayed := _evidence(_request(5, 0.45, 0.50))
	_check(
		(
			String(delayed["dominant_reason"]) == "REACTION_TOO_LATE"
			and not bool(delayed["reaction_viable"])
			and float(delayed["reaction_deadline_s"]) < 0.12
		),
		"same-direction late sample cannot be relabeled an early detection"
	)
	_check(
		(
			bool(brace["time_to_boundary_available"])
			and bool(brace["earliest_deadline_available"])
			and not bool(brace["time_to_impact_available"])
		),
		"supported impulse evidence decomposes boundary and impact clocks"
	)

	var bad := _request(6, 0.0, 0.0)
	bad["com_velocity_x_m_s"] = NAN
	_check(
		(
			String(DetectorScript.evaluate(bad).get("failure_code", ""))
			== "BRACE_DETECTOR_COM_VELOCITY_X_M_S_NONFINITE"
		),
		"nonfinite velocity fails closed"
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
