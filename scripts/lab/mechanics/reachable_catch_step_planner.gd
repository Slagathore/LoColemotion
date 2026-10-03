class_name LabReachableCatchStepPlanner
extends RefCounted
# gdlint: disable=max-line-length

## Pure BR10 candidate scorer and conservative actuator-limited reach clock.
##
## This does not move a limb. It accepts only explicit candidate geometry,
## collision/torque/friction feasibility witnesses, and per-joint travel/speed
## bounds. A selected candidate is permission to attempt a catch, never proof
## of contact, load, bearing, recovery, or walking.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const CONFIGURATION_SCHEMA := "reachable_catch_step_planner_configuration_v1"
const REQUEST_SCHEMA := "reachable_catch_step_request_v1"
const RESULT_SCHEMA := "reachable_catch_step_plan_v1"
const CONFIGURATION_FIELDS: Array[String] = [
	"schema_version",
	"planner_id",
	"physics_hz",
	"actuation_latency_s",
	"touchdown_confirm_ticks",
	"minimum_swing_clearance_m",
	"minimum_support_improvement_m",
	"maximum_candidate_distance_m",
	"deadline_reserve_s",
	"score_time_weight",
	"score_support_weight",
	"root_assist_allowed",
	"foot_pin_allowed",
	"pose_teleport_allowed",
	"automatic_creature_guidance_allowed",
]
const REQUEST_FIELDS: Array[String] = [
	"schema_version",
	"tick",
	"detector_state",
	"reaction_deadline_s",
	"current_support_min_x_m",
	"current_support_max_x_m",
	"hip_world_x_m",
	"hip_world_y_m",
	"current_foot_world_x_m",
	"current_foot_world_y_m",
	"candidates",
]
const CANDIDATE_FIELDS: Array[String] = [
	"candidate_id",
	"target_world_x_m",
	"target_world_y_m",
	"path_minimum_clearance_m",
	"collision_free",
	"friction_feasible",
	"torque_feasible",
	"preexisting_contact",
	"joint_travel_abs_rad",
	"joint_speed_bounds_rad_s",
]


static func compile(configuration: Dictionary) -> Dictionary:
	if not _field_set_matches(configuration, CONFIGURATION_FIELDS):
		return _failure("CATCH_PLANNER_CONFIGURATION_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != CONFIGURATION_SCHEMA:
		return _failure("CATCH_PLANNER_CONFIGURATION_SCHEMA_UNSUPPORTED")
	if not _stable_id(String(configuration.get("planner_id", ""))):
		return _failure("CATCH_PLANNER_ID_INVALID")
	var physics_hz := _positive_integer(configuration.get("physics_hz"))
	var touchdown_ticks := _positive_integer(configuration.get("touchdown_confirm_ticks"))
	if physics_hz < 60 or physics_hz > 240 or touchdown_ticks < 1:
		return _failure("CATCH_PLANNER_TICK_CONFIGURATION_INVALID")
	for field in [
		"actuation_latency_s",
		"minimum_swing_clearance_m",
		"minimum_support_improvement_m",
		"maximum_candidate_distance_m",
		"deadline_reserve_s",
		"score_time_weight",
		"score_support_weight",
	]:
		if not _finite_number(configuration.get(field)) or float(configuration[field]) < 0.0:
			return _failure("CATCH_PLANNER_FINITE_NONNEGATIVE_INVALID:%s" % field)
	if (
		float(configuration["minimum_swing_clearance_m"]) <= 0.0
		or float(configuration["minimum_support_improvement_m"]) <= 0.0
		or float(configuration["maximum_candidate_distance_m"]) <= 0.0
		or float(configuration["score_time_weight"]) <= 0.0
		or float(configuration["score_support_weight"]) <= 0.0
	):
		return _failure("CATCH_PLANNER_POSITIVE_BOUND_INVALID")
	for forbidden in [
		"root_assist_allowed",
		"foot_pin_allowed",
		"pose_teleport_allowed",
		"automatic_creature_guidance_allowed",
	]:
		if typeof(configuration.get(forbidden)) != TYPE_BOOL or bool(configuration[forbidden]):
			return _failure("CATCH_PLANNER_FORBIDDEN_ASSIST_OR_AUTHORITY:%s" % forbidden)
	var compiled := configuration.duplicate(true)
	compiled["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	compiled["claim_boundary"] = (
		"Conservative BR10 candidate scoring and actuator-limited reach-time estimation only. "
		+ "Selection authorizes only an attempted new-contact catch in a later physical fixture. "
		+ "It proves no contact, load, bearing, stance recovery, free-3D bracing or standing, "
		+ "fall arrest, getting up, gait, walking, repair, or guidance."
	)
	return {"ok": true, "configuration": FrozenValueScript.snapshot(compiled)}


static func plan(configuration: Dictionary, request: Dictionary) -> Dictionary:
	var verified := _verify_configuration(configuration)
	if not bool(verified.get("ok", false)):
		return verified
	if not _field_set_matches(request, REQUEST_FIELDS):
		return _failure("CATCH_REQUEST_FIELD_SET_MISMATCH")
	if String(request.get("schema_version", "")) != REQUEST_SCHEMA:
		return _failure("CATCH_REQUEST_SCHEMA_UNSUPPORTED")
	if not request.get("tick") is int or int(request["tick"]) < 0:
		return _failure("CATCH_REQUEST_TICK_INVALID")
	if String(request.get("detector_state", "")) != "BRACE":
		return _failure("CATCH_REQUEST_DETECTOR_STATE_NOT_BRACE")
	for field in [
		"reaction_deadline_s",
		"current_support_min_x_m",
		"current_support_max_x_m",
		"hip_world_x_m",
		"hip_world_y_m",
		"current_foot_world_x_m",
		"current_foot_world_y_m",
	]:
		if not _finite_number(request.get(field)):
			return _failure("CATCH_REQUEST_NONFINITE:%s" % field)
	if (
		float(request["reaction_deadline_s"]) <= 0.0
		or float(request["current_support_min_x_m"]) >= float(request["current_support_max_x_m"])
	):
		return _failure("CATCH_REQUEST_BOUND_INVALID")
	if not request.get("candidates") is Array or (request["candidates"] as Array).is_empty():
		return _failure("CATCH_REQUEST_CANDIDATES_MISSING")

	var evaluated: Array = []
	var seen_ids: Dictionary = {}
	for candidate_value in request["candidates"]:
		if not candidate_value is Dictionary:
			return _failure("CATCH_CANDIDATE_NOT_OBJECT")
		var result := _evaluate_candidate(configuration, request, candidate_value)
		if not bool(result.get("ok", false)):
			return result
		var candidate: Dictionary = result["candidate"]
		if seen_ids.has(String(candidate["candidate_id"])):
			return _failure("CATCH_CANDIDATE_ID_DUPLICATE")
		seen_ids[String(candidate["candidate_id"])] = true
		evaluated.append(candidate)
	evaluated.sort_custom(_candidate_precedes)

	var selected: Dictionary = {}
	for candidate_value in evaluated:
		var candidate: Dictionary = candidate_value
		if bool(candidate["feasible"]):
			selected = candidate
			break
	var output := {
		"schema_version": RESULT_SCHEMA,
		"planner_id": configuration["planner_id"],
		"configuration_sha256": configuration["configuration_sha256"],
		"tick": request["tick"],
		"reaction_deadline_s": request["reaction_deadline_s"],
		"candidate_count": evaluated.size(),
		"candidates": evaluated,
		"selected": not selected.is_empty(),
		"selected_candidate_id": selected.get("candidate_id", ""),
		"predicted_reach_time_s": selected.get("predicted_reach_time_s", -1.0),
		"predicted_contact_tick": selected.get("predicted_contact_tick", -1),
		"selection_is_contact_observation": false,
		"selection_is_bearing_observation": false,
		"new_contact_requested": not selected.is_empty(),
		"root_assist_requested": false,
		"foot_pin_requested": false,
		"pose_teleport_requested": false,
		"automatic_creature_guidance_requested": false,
		"failure_code": "" if not selected.is_empty() else "CATCH_NO_FEASIBLE_CANDIDATE",
		"claim_boundary": configuration["claim_boundary"],
	}
	output["plan_sha256"] = CanonicalJsonScript.sha256(output)
	return {"ok": true, "plan": FrozenValueScript.snapshot(output)}


static func _evaluate_candidate(
	configuration: Dictionary, request: Dictionary, candidate: Dictionary
) -> Dictionary:
	if not _field_set_matches(candidate, CANDIDATE_FIELDS):
		return _failure("CATCH_CANDIDATE_FIELD_SET_MISMATCH")
	var candidate_id := String(candidate.get("candidate_id", ""))
	if not _stable_id(candidate_id):
		return _failure("CATCH_CANDIDATE_ID_INVALID")
	for field in ["target_world_x_m", "target_world_y_m", "path_minimum_clearance_m"]:
		if not _finite_number(candidate.get(field)):
			return _failure("CATCH_CANDIDATE_NONFINITE:%s" % field)
	for field in [
		"collision_free",
		"friction_feasible",
		"torque_feasible",
		"preexisting_contact",
	]:
		if typeof(candidate.get(field)) != TYPE_BOOL:
			return _failure("CATCH_CANDIDATE_BOOL_INVALID:%s" % field)
	var travel := _two_positive_numbers(candidate.get("joint_travel_abs_rad"), true)
	var speeds := _two_positive_numbers(candidate.get("joint_speed_bounds_rad_s"), false)
	if travel.is_empty() or speeds.is_empty():
		return _failure("CATCH_CANDIDATE_JOINT_ENVELOPE_INVALID")
	var dx := float(candidate["target_world_x_m"]) - float(request["hip_world_x_m"])
	var dy := float(candidate["target_world_y_m"]) - float(request["hip_world_y_m"])
	var distance := Vector2(dx, dy).length()
	var travel_time := maxf(
		float(travel[0]) / float(speeds[0]), float(travel[1]) / float(speeds[1])
	)
	var touchdown_time := (
		float(configuration["touchdown_confirm_ticks"]) / float(configuration["physics_hz"])
	)
	var predicted_time := float(configuration["actuation_latency_s"]) + travel_time + touchdown_time
	var usable_deadline := (
		float(request["reaction_deadline_s"]) - float(configuration["deadline_reserve_s"])
	)
	var target_x := float(candidate["target_world_x_m"])
	var current_min := float(request["current_support_min_x_m"])
	var current_max := float(request["current_support_max_x_m"])
	var expanded_min := minf(current_min, target_x)
	var expanded_max := maxf(current_max, target_x)
	var support_improvement := (expanded_max - expanded_min) - (current_max - current_min)
	var reasons: Array[String] = []
	if not bool(candidate["collision_free"]):
		reasons.append("CATCH_PATH_COLLISION")
	if not bool(candidate["friction_feasible"]):
		reasons.append("CATCH_TARGET_FRICTION_INFEASIBLE")
	if not bool(candidate["torque_feasible"]):
		reasons.append("CATCH_TARGET_TORQUE_INFEASIBLE")
	if bool(candidate["preexisting_contact"]):
		reasons.append("CATCH_TARGET_NOT_NEW_CONTACT")
	if (
		float(candidate["path_minimum_clearance_m"])
		< float(configuration["minimum_swing_clearance_m"])
	):
		reasons.append("CATCH_SWING_CLEARANCE_INSUFFICIENT")
	if distance > float(configuration["maximum_candidate_distance_m"]):
		reasons.append("CATCH_TARGET_DISTANCE_EXCEEDED")
	if support_improvement < float(configuration["minimum_support_improvement_m"]):
		reasons.append("CATCH_SUPPORT_IMPROVEMENT_INSUFFICIENT")
	if usable_deadline <= 0.0 or predicted_time > usable_deadline:
		reasons.append("CATCH_REACH_DEADLINE_MISSED")
	var score := (
		float(configuration["score_support_weight"]) * support_improvement
		- float(configuration["score_time_weight"]) * predicted_time
	)
	return {
		"ok": true,
		"candidate":
		{
			"candidate_id": candidate_id,
			"feasible": reasons.is_empty(),
			"failure_reasons": reasons,
			"target_world_x_m": candidate["target_world_x_m"],
			"target_world_y_m": candidate["target_world_y_m"],
			"hip_distance_m": distance,
			"path_minimum_clearance_m": candidate["path_minimum_clearance_m"],
			"predicted_reach_time_s": predicted_time,
			"predicted_contact_tick":
			int(request["tick"]) + ceili(predicted_time * float(configuration["physics_hz"])),
			"usable_deadline_s": usable_deadline,
			"support_interval_before_m": [current_min, current_max],
			"support_interval_after_m": [expanded_min, expanded_max],
			"support_improvement_m": support_improvement,
			"score": score,
			"joint_travel_abs_rad": travel,
			"joint_speed_bounds_rad_s": speeds,
		}
	}


static func _verify_configuration(configuration: Dictionary) -> Dictionary:
	var raw: Dictionary = {}
	for field in CONFIGURATION_FIELDS:
		if not configuration.has(field):
			return _failure("CATCH_PLANNER_CONFIGURATION_INCOMPLETE")
		raw[field] = configuration[field]
	var rebuilt := compile(raw)
	if not bool(rebuilt.get("ok", false)):
		return rebuilt
	if (
		CanonicalJsonScript.stringify(rebuilt["configuration"])
		!= CanonicalJsonScript.stringify(configuration)
	):
		return _failure("CATCH_PLANNER_CONFIGURATION_DIGEST_MISMATCH")
	return {"ok": true}


static func _candidate_precedes(left: Dictionary, right: Dictionary) -> bool:
	if bool(left["feasible"]) != bool(right["feasible"]):
		return bool(left["feasible"])
	if absf(float(left["score"]) - float(right["score"])) > 1.0e-12:
		return float(left["score"]) > float(right["score"])
	return String(left["candidate_id"]) < String(right["candidate_id"])


static func _two_positive_numbers(value: Variant, zero_allowed: bool) -> Array:
	if not value is Array or (value as Array).size() != 2:
		return []
	var result: Array = []
	for item in value:
		if (
			not _finite_number(item)
			or float(item) < 0.0
			or (not zero_allowed and float(item) == 0.0)
		):
			return []
		result.append(float(item))
	return result


static func _field_set_matches(value: Dictionary, fields: Array[String]) -> bool:
	var actual: Array = value.keys()
	actual.sort()
	var expected: Array = fields.duplicate()
	expected.sort()
	return actual == expected


static func _positive_integer(value: Variant) -> int:
	if value is int and int(value) > 0:
		return int(value)
	return -1


static func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _stable_id(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[A-Za-z][A-Za-z0-9._-]{0,159}$")
	return regex.search(value) != null


static func _failure(code: String, details: Variant = null) -> Dictionary:
	return {"ok": false, "failure_code": code, "details": details}
