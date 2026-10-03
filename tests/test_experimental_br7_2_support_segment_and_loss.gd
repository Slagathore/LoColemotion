extends SceneTree

## BR7.2 planar static/capture margins and support-loss supervision.

const SegmentScript := preload("res://scripts/lab/mechanics/planar_support_segment.gd")
const SupervisorScript := preload("res://scripts/lab/mechanics/planar_support_supervisor.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR7.2 support segment and loss ===")
	var centered := SegmentScript.evaluate(_request(0.0, 0.0, true, true))
	var centered_value: Dictionary = centered["support"]
	_check(
		(
			bool(centered.get("ok", false))
			and absf(float(centered_value["static_margin_m"]) - 0.5) <= 1.0e-12
			and absf(float(centered_value["capture_margin_m"]) - 0.5) <= 1.0e-12
		),
		"centered static body has the exact half-span support and capture margin"
	)

	var moving_right := SegmentScript.evaluate(_request(0.0, 1.0, true, true))
	var moving_value: Dictionary = moving_right["support"]
	var expected_capture := 1.0 / sqrt(9.8 / 0.8)
	_check(
		(
			absf(float(moving_value["capture_point_x_m"]) - expected_capture) <= 1.0e-12
			and float(moving_value["capture_margin_m"]) < 0.5
		),
		"rightward velocity moves the linear capture point toward the right boundary"
	)

	var outside_right := SegmentScript.evaluate(_request(0.6, 0.0, true, true))
	_check(
		(
			not bool(outside_right["support"]["static_inside"])
			and String(outside_right["support"]["static_loss_direction"]) == "right"
		),
		"outside-right COM predicts the right loss direction"
	)
	var outside_left := SegmentScript.evaluate(_request(-0.6, 0.0, true, true))
	_check(
		(
			not bool(outside_left["support"]["static_inside"])
			and String(outside_left["support"]["static_loss_direction"]) == "left"
		),
		"mirrored outside-left COM predicts the left loss direction"
	)

	var single := SegmentScript.evaluate(_request(-0.5, 0.0, true, false))
	_check(
		(
			int(single["support"]["bearing_support_count"]) == 1
			and absf(float(single["support"]["static_margin_m"])) <= 1.0e-12
		),
		"one bearing support degenerates honestly to a zero-width point"
	)
	var single_offpoint := SegmentScript.evaluate(_request(0.0, 0.0, true, false))
	_check(
		(
			float(single_offpoint["support"]["static_margin_m"]) < 0.0
			and String(single_offpoint["support"]["static_loss_direction"]) == "right"
		),
		"COM away from the sole support is outside the degenerate segment"
	)

	var supervisor = SupervisorScript.new()
	var initial := supervisor.update(0, true, true, true)
	var retained := supervisor.update(1, true, true, true)
	var lost := supervisor.update(2, true, false, false)
	_check(
		(
			String(initial["mode"]) == "STANCE"
			and String(retained["mode"]) == "STANCE"
			and (retained["events"] as Array).is_empty()
		),
		"stable bearing set does not chatter"
	)
	_check(
		(
			String(lost["mode"]) == "DEGRADED_SINGLE_SUPPORT"
			and String(lost["response"]) == "DECLARE_INFEASIBLE_STOP"
			and (lost["events"] as Array).size() == 1
			and String(lost["events"][0]["event"]) == "SUPPORT_LOST"
			and String(lost["events"][0]["support_id"]) == "right"
		),
		"right support loss emits one reasoned event and fail-closed response"
	)
	_check(
		(
			not bool(lost["automatic_force_application"])
			and not bool(lost["automatic_creature_guidance"])
		),
		"supervisor event applies no hidden force and authorizes no guidance"
	)

	var malformed := _request(0.0, 0.0, true, true)
	malformed["com_height_m"] = 0.0
	_check(
		(
			String(SegmentScript.evaluate(malformed).get("failure_code", ""))
			== "SUPPORT_SEGMENT_BOUNDS_INVALID"
		),
		"nonphysical capture-height request fails closed"
	)
	_finish()


static func _request(
	com_x: float, velocity_x: float, left_bearing: bool, right_bearing: bool
) -> Dictionary:
	return {
		"schema_version": "planar_support_segment_request_v1",
		"com_x_m": com_x,
		"com_velocity_x_m_s": velocity_x,
		"com_height_m": 0.8,
		"gravity_m_s2": 9.8,
		"left_support_x_m": -0.5,
		"right_support_x_m": 0.5,
		"left_bearing": left_bearing,
		"right_bearing": right_bearing,
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
