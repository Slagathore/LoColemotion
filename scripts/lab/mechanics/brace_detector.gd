class_name LabBraceDetector
extends RefCounted
# gdlint: disable=max-line-length

## BR8 scaffold-preserving loss-of-viability detector.
##
## This object is an observer only. It converts declared planar support,
## center-of-mass, velocity, and clearance measurements into decomposed urgency
## evidence. It never applies a force, chooses a catch contact, or claims that a
## brace was physically executed.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA_VERSION := "brace_detection_request_v1"
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"tick",
	"com_x_m",
	"com_velocity_x_m_s",
	"com_height_m",
	"vertical_velocity_m_s",
	"body_clearance_m",
	"gravity_m_s2",
	"support_min_x_m",
	"support_max_x_m",
	"bearing_support_count",
	"brace_margin_m",
	"precarious_margin_m",
	"release_margin_m",
	"reaction_time_s",
	"safety_time_s",
	"brace_trigger_time_s",
	"precarious_trigger_time_s",
	"airborne",
]
const NUMERIC_FIELDS: Array[String] = [
	"com_x_m",
	"com_velocity_x_m_s",
	"com_height_m",
	"vertical_velocity_m_s",
	"body_clearance_m",
	"gravity_m_s2",
	"support_min_x_m",
	"support_max_x_m",
	"brace_margin_m",
	"precarious_margin_m",
	"release_margin_m",
	"reaction_time_s",
	"safety_time_s",
	"brace_trigger_time_s",
	"precarious_trigger_time_s",
]


static func evaluate(request: Dictionary) -> Dictionary:
	var keys: Array = request.keys()
	keys.sort()
	var expected: Array = REQUIRED_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		return _failure("BRACE_DETECTOR_FIELD_SET_MISMATCH")
	if String(request.get("schema_version", "")) != SCHEMA_VERSION:
		return _failure("BRACE_DETECTOR_SCHEMA_UNSUPPORTED")
	var tick_value: Variant = request.get("tick")
	if (
		typeof(tick_value) not in [TYPE_INT, TYPE_FLOAT]
		or not is_finite(float(tick_value))
		or float(tick_value) != floorf(float(tick_value))
		or int(tick_value) < 0
	):
		return _failure("BRACE_DETECTOR_TICK_INVALID")
	for field in NUMERIC_FIELDS:
		var value: Variant = request.get(field)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return _failure("BRACE_DETECTOR_%s_NONFINITE" % field.to_upper())
	var support_count_value: Variant = request.get("bearing_support_count")
	if (
		typeof(support_count_value) not in [TYPE_INT, TYPE_FLOAT]
		or not is_finite(float(support_count_value))
		or float(support_count_value) != floorf(float(support_count_value))
		or int(support_count_value) < 0
		or int(support_count_value) > 2
	):
		return _failure("BRACE_DETECTOR_SUPPORT_COUNT_INVALID")
	if typeof(request.get("airborne")) != TYPE_BOOL:
		return _failure("BRACE_DETECTOR_AIRBORNE_INVALID")

	var height := float(request["com_height_m"])
	var clearance := float(request["body_clearance_m"])
	var gravity := float(request["gravity_m_s2"])
	var support_min := float(request["support_min_x_m"])
	var support_max := float(request["support_max_x_m"])
	var brace_margin := float(request["brace_margin_m"])
	var precarious_margin := float(request["precarious_margin_m"])
	var release_margin := float(request["release_margin_m"])
	var reaction_time := float(request["reaction_time_s"])
	var safety_time := float(request["safety_time_s"])
	var brace_trigger_time := float(request["brace_trigger_time_s"])
	var precarious_trigger_time := float(request["precarious_trigger_time_s"])
	if (
		height <= 0.0
		or clearance < 0.0
		or gravity <= 0.0
		or support_min >= support_max
		or brace_margin < 0.0
		or precarious_margin <= brace_margin
		or release_margin <= precarious_margin
		or reaction_time <= 0.0
		or safety_time < 0.0
		or brace_trigger_time <= reaction_time + safety_time
		or precarious_trigger_time <= brace_trigger_time
	):
		return _failure("BRACE_DETECTOR_BOUNDS_INVALID")

	var com_x := float(request["com_x_m"])
	var velocity_x := float(request["com_velocity_x_m_s"])
	var capture_x := com_x + velocity_x / sqrt(gravity / height)
	var static_margin := minf(com_x - support_min, support_max - com_x)
	var capture_margin := minf(capture_x - support_min, support_max - capture_x)
	var static_direction := _loss_direction(com_x, support_min, support_max)
	var capture_direction := _loss_direction(capture_x, support_min, support_max)
	var boundary_estimate := _time_to_boundary(com_x, velocity_x, support_min, support_max)
	var impact_estimate := (
		_time_to_impact(
			clearance,
			float(request["vertical_velocity_m_s"]),
			gravity,
		)
		if bool(request["airborne"])
		else {"available": false, "seconds": -1.0}
	)
	var deadline := _earliest_deadline(boundary_estimate, impact_estimate)
	var reaction_deadline_s := (
		float(deadline["seconds"]) - safety_time if bool(deadline["available"]) else -1.0
	)
	var reaction_viable := not bool(deadline["available"]) or reaction_deadline_s >= reaction_time
	var minimum_margin := minf(static_margin, capture_margin)
	var support_count := int(support_count_value)

	var recommendation := "STAND"
	var reason := "MARGINS_AND_DEADLINES_SAFE"
	if support_count == 0:
		recommendation = "BRACE"
		reason = "NO_BEARING_SUPPORT"
	elif static_margin < 0.0:
		recommendation = "BRACE"
		reason = "STATIC_MARGIN_EXHAUSTED"
	elif not reaction_viable:
		recommendation = "BRACE"
		reason = "REACTION_TOO_LATE"
	elif static_margin <= brace_margin:
		recommendation = "BRACE"
		reason = "STATIC_MARGIN_BRACE"
	elif capture_margin <= brace_margin:
		recommendation = "BRACE"
		reason = "CAPTURE_MARGIN_BRACE"
	elif (
		bool(boundary_estimate["available"])
		and float(boundary_estimate["seconds"]) <= brace_trigger_time
	):
		recommendation = "BRACE"
		reason = "BOUNDARY_DEADLINE_BRACE"
	elif minimum_margin <= precarious_margin:
		recommendation = "PRECARIOUS"
		reason = "SUPPORT_MARGIN_PRECARIOUS"
	elif (
		bool(boundary_estimate["available"])
		and float(boundary_estimate["seconds"]) <= precarious_trigger_time
	):
		recommendation = "PRECARIOUS"
		reason = "BOUNDARY_DEADLINE_PRECARIOUS"

	var safe_release_candidate := (
		support_count > 0
		and minimum_margin >= release_margin
		and (
			not bool(deadline["available"]) or float(deadline["seconds"]) > precarious_trigger_time
		)
	)
	var urgency := 0.0
	if recommendation == "PRECARIOUS":
		urgency = 0.5
	elif recommendation == "BRACE":
		urgency = 1.0
	return {
		"ok": true,
		"evidence":
		(
			FrozenValueScript
			. snapshot(
				{
					"schema_version": "brace_detection_evidence_v1",
					"tick": int(tick_value),
					"recommended_state": recommendation,
					"dominant_reason": reason,
					"urgency": urgency,
					"bearing_support_count": support_count,
					"static_margin_m": static_margin,
					"capture_margin_m": capture_margin,
					"minimum_margin_m": minimum_margin,
					"capture_point_x_m": capture_x,
					"static_loss_direction": static_direction,
					"capture_loss_direction": capture_direction,
					"time_to_boundary_available": bool(boundary_estimate["available"]),
					"time_to_boundary_s": float(boundary_estimate["seconds"]),
					"time_to_impact_available": bool(impact_estimate["available"]),
					"time_to_impact_s": float(impact_estimate["seconds"]),
					"earliest_deadline_available": bool(deadline["available"]),
					"earliest_deadline_s": float(deadline["seconds"]),
					"reaction_deadline_s": reaction_deadline_s,
					"reaction_viable": reaction_viable,
					"safe_release_candidate": safe_release_candidate,
					"planar_scaffold_observation_only": true,
					"automatic_force_application": false,
					"automatic_creature_guidance": false,
				}
			)
		),
	}


static func _time_to_boundary(
	com_x: float, velocity_x: float, support_min: float, support_max: float
) -> Dictionary:
	if absf(velocity_x) <= 1.0e-12:
		return {"available": false, "seconds": -1.0}
	var distance := support_max - com_x if velocity_x > 0.0 else com_x - support_min
	return {"available": true, "seconds": maxf(0.0, distance / absf(velocity_x))}


static func _time_to_impact(
	clearance_m: float, vertical_velocity_m_s: float, gravity_m_s2: float
) -> Dictionary:
	var discriminant := (
		vertical_velocity_m_s * vertical_velocity_m_s + 2.0 * gravity_m_s2 * clearance_m
	)
	var seconds := (vertical_velocity_m_s + sqrt(maxf(0.0, discriminant))) / gravity_m_s2
	return {"available": true, "seconds": maxf(0.0, seconds)}


static func _earliest_deadline(boundary: Dictionary, impact: Dictionary) -> Dictionary:
	var values: Array[float] = []
	if bool(boundary["available"]):
		values.append(float(boundary["seconds"]))
	if bool(impact["available"]):
		values.append(float(impact["seconds"]))
	if values.is_empty():
		return {"available": false, "seconds": -1.0}
	var earliest := values[0]
	for value in values:
		earliest = minf(earliest, value)
	return {"available": true, "seconds": earliest}


static func _loss_direction(value: float, support_min: float, support_max: float) -> String:
	if value < support_min:
		return "left"
	if value > support_max:
		return "right"
	return "inside"


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
