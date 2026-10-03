extends SceneTree
# gdlint: disable=max-line-length

## BR10.0 pure reach/deadline scoring. Selection is deliberately not contact.

const PlannerScript := preload("res://scripts/lab/mechanics/reachable_catch_step_planner.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR10.0 reachable catch planning ===")
	var built := PlannerScript.compile(_configuration())
	_check(bool(built.get("ok", false)), "strict catch-planner configuration seals")
	if not bool(built.get("ok", false)):
		printerr("  build_failure=", built)
		_finish()
		return
	var configuration: Dictionary = built["configuration"]
	var request := _request()
	var planned := PlannerScript.plan(configuration, request)
	_check(bool(planned.get("ok", false)), "finite candidate set produces one auditable plan")
	if not bool(planned.get("ok", false)):
		printerr("  plan_failure=", planned)
		_finish()
		return
	var plan: Dictionary = planned["plan"]
	_check(
		bool(plan["selected"]) and String(plan["selected_candidate_id"]) == "wide_right",
		"highest-scoring feasible support-expanding target wins deterministically"
	)
	_check(
		(
			float(plan["predicted_reach_time_s"]) < float(plan["reaction_deadline_s"])
			and int(plan["predicted_contact_tick"]) > int(plan["tick"])
		),
		"selected target retains a conservative actuator-limited contact clock"
	)
	_check(
		(
			not bool(plan["selection_is_contact_observation"])
			and not bool(plan["selection_is_bearing_observation"])
			and bool(plan["new_contact_requested"])
		),
		"planning requests a new contact without inventing contact or bearing evidence"
	)
	_check(
		(
			not bool(plan["root_assist_requested"])
			and not bool(plan["foot_pin_requested"])
			and not bool(plan["pose_teleport_requested"])
			and not bool(plan["automatic_creature_guidance_requested"])
		),
		"plan contains no root rescue, pin, teleport, or guidance channel"
	)
	var candidates: Array = plan["candidates"]
	_check(
		(
			candidates.size() == 4
			and bool((candidates[0] as Dictionary)["feasible"])
			and bool((candidates[1] as Dictionary)["feasible"])
			and not bool((candidates[2] as Dictionary)["feasible"])
			and not bool((candidates[3] as Dictionary)["feasible"])
		),
		"feasible candidates sort before specifically rejected candidates"
	)
	_check(
		_candidate_has_reason(candidates, "blocked_right", "CATCH_PATH_COLLISION"),
		"collision witness rejects an otherwise attractive target specifically"
	)
	_check(
		_candidate_has_reason(candidates, "late_right", "CATCH_REACH_DEADLINE_MISSED"),
		"actuator-limited target that misses reserve-adjusted deadline is rejected"
	)

	var no_candidate_request := request.duplicate(true)
	for candidate_value in no_candidate_request["candidates"]:
		(candidate_value as Dictionary)["collision_free"] = false
	var none := PlannerScript.plan(configuration, no_candidate_request)
	_check(
		(
			bool(none.get("ok", false))
			and not bool(none["plan"]["selected"])
			and String(none["plan"]["failure_code"]) == "CATCH_NO_FEASIBLE_CANDIDATE"
		),
		"complete but infeasible candidate set returns an honest no-catch result"
	)
	var mutated_configuration := configuration.duplicate(true)
	mutated_configuration["maximum_candidate_distance_m"] = 2.0
	_check(
		(
			String(PlannerScript.plan(mutated_configuration, request).get("failure_code", ""))
			== "CATCH_PLANNER_CONFIGURATION_DIGEST_MISMATCH"
		),
		"post-seal configuration mutation fails closed"
	)
	var wrong_state := request.duplicate(true)
	wrong_state["detector_state"] = "STAND"
	_check(
		(
			String(PlannerScript.plan(configuration, wrong_state).get("failure_code", ""))
			== "CATCH_REQUEST_DETECTOR_STATE_NOT_BRACE"
		),
		"catch planning refuses a request outside the declared BRACE state"
	)
	var forged_contact := request.duplicate(true)
	(forged_contact["candidates"][0] as Dictionary)["preexisting_contact"] = true
	var forged_result := PlannerScript.plan(configuration, forged_contact)
	_check(
		_candidate_has_reason(
			forged_result["plan"]["candidates"], "wide_right", "CATCH_TARGET_NOT_NEW_CONTACT"
		),
		"an already-bearing target cannot masquerade as a new-contact catch"
	)
	_finish()


static func _configuration() -> Dictionary:
	return {
		"schema_version": "reachable_catch_step_planner_configuration_v1",
		"planner_id": "br10_planar_reachable_catch",
		"physics_hz": 120,
		"actuation_latency_s": 0.03,
		"touchdown_confirm_ticks": 3,
		"minimum_swing_clearance_m": 0.025,
		"minimum_support_improvement_m": 0.10,
		"maximum_candidate_distance_m": 0.90,
		"deadline_reserve_s": 0.05,
		"score_time_weight": 1.0,
		"score_support_weight": 1.0,
		"root_assist_allowed": false,
		"foot_pin_allowed": false,
		"pose_teleport_allowed": false,
		"automatic_creature_guidance_allowed": false,
	}


static func _request() -> Dictionary:
	return {
		"schema_version": "reachable_catch_step_request_v1",
		"tick": 100,
		"detector_state": "BRACE",
		"reaction_deadline_s": 0.40,
		"current_support_min_x_m": -0.30,
		"current_support_max_x_m": 0.0,
		"hip_world_x_m": 0.20,
		"hip_world_y_m": 0.70,
		"current_foot_world_x_m": 0.20,
		"current_foot_world_y_m": 0.25,
		"candidates":
		[
			_candidate("wide_right", 0.65, [0.40, 0.80], [4.0, 6.0], true),
			_candidate("near_right", 0.45, [0.20, 0.35], [4.0, 6.0], true),
			_candidate("blocked_right", 0.75, [0.30, 0.50], [4.0, 6.0], false),
			_candidate("late_right", 0.85, [1.80, 2.40], [2.0, 2.0], true),
		],
	}


static func _candidate(
	candidate_id: String, target_x: float, travel: Array, speeds: Array, collision_free: bool
) -> Dictionary:
	return {
		"candidate_id": candidate_id,
		"target_world_x_m": target_x,
		"target_world_y_m": 0.055,
		"path_minimum_clearance_m": 0.08,
		"collision_free": collision_free,
		"friction_feasible": true,
		"torque_feasible": true,
		"preexisting_contact": false,
		"joint_travel_abs_rad": travel,
		"joint_speed_bounds_rad_s": speeds,
	}


static func _candidate_has_reason(candidates: Array, candidate_id: String, reason: String) -> bool:
	for candidate_value in candidates:
		var candidate: Dictionary = candidate_value
		if String(candidate["candidate_id"]) == candidate_id:
			return (candidate["failure_reasons"] as Array).has(reason)
	return false


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
