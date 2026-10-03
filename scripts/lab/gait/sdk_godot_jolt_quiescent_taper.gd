extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## Independent Godot/Jolt GDScript temporal mirror for QSDK-R23D10.
##
## This script never creates a PhysicsServer body, scene node, model, or world.
## It mirrors only the prospectively frozen terminal scheduler.

const ACTIVE_MODE := "active_neutral_acquisition"
const TAPER_MODE := "active_quiescent_taper"
const PASSIVE_MODE := "irreversible_zero_actuation_stability"
const CONFIRMED_REASON := "support_pose_quiescence_confirmed"
const DEADLINE_REASON := "deadline_forced_without_quiescence_confirmation"

const TERMINAL_STEPS := 900
const MAXIMUM_ACTIVE_STEPS := 540
const MINIMUM_TAPER_STEPS := 120
const MINIMUM_PASSIVE_STEPS := 360
const ACTUATOR_COUNT := 8
const SCALE_DENOMINATOR := 120
const COARSE_MAXIMUM_TILT_RAD := 0.035
const COARSE_MAXIMUM_JOINT_ERROR_RAD := 0.32
const TIGHT_MAXIMUM_TILT_RAD := 0.01
const TIGHT_MAXIMUM_JOINT_ERROR_RAD := 0.2

const SUPPORTED := [true, true, true, true]
const PARTIAL := [true, true, true, false]
const TIGHT := {
	"contacts": SUPPORTED,
	"torso_tilt_rad": 0.005,
	"maximum_absolute_joint_position_error_rad": 0.18,
}
const COARSE_ONLY := {
	"contacts": SUPPORTED,
	"torso_tilt_rad": 0.03,
	"maximum_absolute_joint_position_error_rad": 0.30,
}
const PARTIAL_TIGHT := {
	"contacts": PARTIAL,
	"torso_tilt_rad": 0.005,
	"maximum_absolute_joint_position_error_rad": 0.18,
}


static func initial_state() -> Dictionary:
	return {
		"next_step": 0,
		"mode": ACTIVE_MODE,
		"taper_step_count": 0,
		"confirmation_satisfied": false,
		"handoff_after_active_step": null,
		"first_passive_step": null,
		"handoff_reason": null,
		"active_step_count": 0,
		"passive_step_count": 0,
		"active_native_application_count": 0,
		"passive_native_application_count": 0,
		"taper_reset_count": 0,
		"first_post_handoff_contact_loss_step": null,
		"post_handoff_contact_loss_step_count": 0,
	}


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}


static func _observation_valid(observation: Dictionary) -> bool:
	var contacts: Variant = observation.get("contacts")
	if typeof(contacts) != TYPE_ARRAY or (contacts as Array).size() != 4:
		return false
	for contact in contacts as Array:
		if typeof(contact) != TYPE_BOOL:
			return false
	var tilt: Variant = observation.get("torso_tilt_rad")
	var error: Variant = observation.get(
		"maximum_absolute_joint_position_error_rad"
	)
	if not [TYPE_FLOAT, TYPE_INT].has(typeof(tilt)) or not [TYPE_FLOAT, TYPE_INT].has(typeof(error)):
		return false
	return is_finite(float(tilt)) and float(tilt) >= 0.0 and is_finite(float(error)) and float(error) >= 0.0


static func _all_four(observation: Dictionary) -> bool:
	for contact in observation["contacts"] as Array:
		if not bool(contact):
			return false
	return true


static func _coarse(observation: Dictionary) -> bool:
	return (
		_all_four(observation)
		and float(observation["torso_tilt_rad"]) <= COARSE_MAXIMUM_TILT_RAD
		and float(observation["maximum_absolute_joint_position_error_rad"])
		<= COARSE_MAXIMUM_JOINT_ERROR_RAD
	)


static func _tight(observation: Dictionary) -> bool:
	return (
		_all_four(observation)
		and float(observation["torso_tilt_rad"]) <= TIGHT_MAXIMUM_TILT_RAD
		and float(observation["maximum_absolute_joint_position_error_rad"])
		<= TIGHT_MAXIMUM_JOINT_ERROR_RAD
	)


static func expected_velocity_scale(state: Dictionary) -> Dictionary:
	match String(state.get("mode", "")):
		ACTIVE_MODE:
			return {"ok": true, "numerator": 120, "denominator": 120}
		TAPER_MODE:
			return {
				"ok": true,
				"numerator": maxi(1, MINIMUM_TAPER_STEPS - int(state["taper_step_count"])),
				"denominator": 120,
			}
		PASSIVE_MODE:
			return {"ok": true, "numerator": 0, "denominator": 120}
	return _failure("R23D10_STATE_MODE_INVALID")


static func _handoff(state: Dictionary, step: int, confirmed: bool) -> Dictionary:
	var result := state.duplicate(true)
	result["mode"] = PASSIVE_MODE
	result["confirmation_satisfied"] = confirmed
	result["handoff_after_active_step"] = step
	result["first_passive_step"] = step + 1
	result["handoff_reason"] = CONFIRMED_REASON if confirmed else DEADLINE_REASON
	return result


static func observe_completed_step(
	state: Dictionary,
	observation: Dictionary,
	native_application_count: int,
	velocity_scale_numerator: int,
	velocity_scale_denominator: int,
) -> Dictionary:
	var step := int(state.get("next_step", -1))
	var mode := String(state.get("mode", ""))
	if step < 0 or step >= TERMINAL_STEPS:
		return _failure("R23D10_STEP_OUTSIDE_HORIZON")
	if not [ACTIVE_MODE, TAPER_MODE, PASSIVE_MODE].has(mode):
		return _failure("R23D10_STATE_MODE_INVALID")
	if not _observation_valid(observation):
		return _failure("R23D10_OBSERVATION_INVALID")
	var scale := expected_velocity_scale(state)
	if (
		not bool(scale.get("ok", false))
		or velocity_scale_numerator != int(scale["numerator"])
		or velocity_scale_denominator != int(scale["denominator"])
	):
		return _failure("R23D10_VELOCITY_SCALE_MISMATCH")
	var expected_applications := 0 if mode == PASSIVE_MODE else ACTUATOR_COUNT
	if native_application_count != expected_applications:
		return _failure("R23D10_APPLICATION_COUNT_MISMATCH")

	var pre_taper_count := int(state["taper_step_count"])
	var coarse := _coarse(observation)
	var tight := _tight(observation)
	var transitioned := false
	var reset := false
	var next := state.duplicate(true)
	next["next_step"] = step + 1
	if mode != PASSIVE_MODE:
		next["active_step_count"] = int(state["active_step_count"]) + 1
		next["active_native_application_count"] = (
			int(state["active_native_application_count"]) + native_application_count
		)
		if mode == ACTIVE_MODE:
			if step == MAXIMUM_ACTIVE_STEPS - 1:
				next = _handoff(next, step, false)
				transitioned = true
			elif coarse:
				next["mode"] = TAPER_MODE
				next["taper_step_count"] = 0
				transitioned = true
		elif coarse:
			var post_taper_count := mini(MINIMUM_TAPER_STEPS, pre_taper_count + 1)
			next["taper_step_count"] = post_taper_count
			if post_taper_count >= MINIMUM_TAPER_STEPS and tight:
				next = _handoff(next, step, true)
				transitioned = true
			elif step == MAXIMUM_ACTIVE_STEPS - 1:
				next = _handoff(next, step, false)
				transitioned = true
		elif step == MAXIMUM_ACTIVE_STEPS - 1:
			next = _handoff(next, step, false)
			transitioned = true
		else:
			next["mode"] = ACTIVE_MODE
			next["taper_step_count"] = 0
			next["taper_reset_count"] = int(state["taper_reset_count"]) + 1
			transitioned = true
			reset = true
	else:
		next["passive_step_count"] = int(state["passive_step_count"]) + 1
		next["passive_native_application_count"] = (
			int(state["passive_native_application_count"]) + native_application_count
		)
		if not _all_four(observation):
			next["post_handoff_contact_loss_step_count"] = (
				int(state["post_handoff_contact_loss_step_count"]) + 1
			)
			if state["first_post_handoff_contact_loss_step"] == null:
				next["first_post_handoff_contact_loss_step"] = step

	return {
		"ok": true,
		"failure_code": "",
		"state": next,
		"receipt": {
			"step": step,
			"mode": mode,
			"all_four_contacts": _all_four(observation),
			"torso_tilt_rad": float(observation["torso_tilt_rad"]),
			"maximum_absolute_joint_position_error_rad": float(
				observation["maximum_absolute_joint_position_error_rad"]
			),
			"coarse_pose_satisfied": coarse,
			"tight_pose_satisfied": tight,
			"pre_step_taper_count": pre_taper_count,
			"post_step_taper_count": int(next["taper_step_count"]),
			"velocity_scale_numerator": velocity_scale_numerator,
			"velocity_scale_denominator": velocity_scale_denominator,
			"native_application_count": native_application_count,
			"transition_after_step": transitioned,
			"taper_reset_after_step": reset,
			"next_mode": String(next["mode"]),
			"handoff_reason": (
				next["handoff_reason"]
				if transitioned and String(next["mode"]) == PASSIVE_MODE
				else null
			),
		},
	}


static func outcome(state: Dictionary) -> Dictionary:
	if int(state.get("next_step", -1)) != TERMINAL_STEPS:
		return _failure("R23D10_OUTCOME_BEFORE_HORIZON")
	var first_passive: Variant = state["first_passive_step"]
	var passed := (
		bool(state["confirmation_satisfied"])
		and String(state["handoff_reason"]) == CONFIRMED_REASON
		and first_passive != null
		and int(first_passive) <= MAXIMUM_ACTIVE_STEPS
		and int(state["passive_step_count"]) >= MINIMUM_PASSIVE_STEPS
		and int(state["passive_native_application_count"]) == 0
		and int(state["post_handoff_contact_loss_step_count"]) == 0
		and String(state["mode"]) == PASSIVE_MODE
	)
	var result := state.duplicate(true)
	result["ok"] = true
	result["failure_code"] = ""
	result["quiescent_taper_gate_passed"] = passed
	return result


static func simulate(observations: Array) -> Dictionary:
	if observations.size() != TERMINAL_STEPS:
		return _failure("R23D10_OBSERVATION_HORIZON_INVALID")
	var state := initial_state()
	for observation_value in observations:
		if typeof(observation_value) != TYPE_DICTIONARY:
			return _failure("R23D10_OBSERVATION_INVALID")
		var scale := expected_velocity_scale(state)
		var applications := 0 if String(state["mode"]) == PASSIVE_MODE else 8
		var transition := observe_completed_step(
			state,
			observation_value as Dictionary,
			applications,
			int(scale["numerator"]),
			int(scale["denominator"]),
		)
		if not bool(transition.get("ok", false)):
			return transition
		state = transition["state"]
	return outcome(state)


static func _repeat(observation: Dictionary, count: int) -> Array:
	var result: Array = []
	for _index in count:
		result.append(observation)
	return result


static func run_zero_world_preflight() -> Dictionary:
	var first := simulate(_repeat(TIGHT, 900))
	var delayed := _repeat(PARTIAL_TIGHT, 313)
	delayed.append_array(_repeat(TIGHT, 587))
	var delayed_outcome := simulate(delayed)
	var reset_rows := _repeat(PARTIAL_TIGHT, 10)
	reset_rows.append_array(_repeat(TIGHT, 51))
	reset_rows.append(PARTIAL_TIGHT)
	reset_rows.append_array(_repeat(TIGHT, 838))
	var reset_outcome := simulate(reset_rows)
	var deadline := simulate(_repeat(COARSE_ONLY, 900))
	var loss_rows := _repeat(TIGHT, 900)
	loss_rows[500] = PARTIAL_TIGHT
	var loss := simulate(loss_rows)
	if (
		not bool(first.get("quiescent_taper_gate_passed", false))
		or int(first.get("handoff_after_active_step", -1)) != 120
		or not bool(delayed_outcome.get("quiescent_taper_gate_passed", false))
		or int(delayed_outcome.get("handoff_after_active_step", -1)) != 433
		or int(reset_outcome.get("taper_reset_count", -1)) != 1
		or int(reset_outcome.get("handoff_after_active_step", -1)) != 182
		or bool(deadline.get("quiescent_taper_gate_passed", true))
		or int(deadline.get("handoff_after_active_step", -1)) != 539
		or bool(loss.get("quiescent_taper_gate_passed", true))
		or int(loss.get("first_post_handoff_contact_loss_step", -1)) != 500
	):
		return _failure("R23D10_GJT_CANARY_FAILED")

	var mutations := 0
	var transition := observe_completed_step(initial_state(), PARTIAL_TIGHT, 8, 120, 120)
	if String((transition.get("state", {}) as Dictionary).get("mode", "")) != ACTIVE_MODE:
		return _failure("R23D10_GJT_MUTATION_COARSE_CONTACT")
	mutations += 1
	var taper := initial_state()
	taper["next_step"] = 10
	taper["mode"] = TAPER_MODE
	taper["taper_step_count"] = 5
	transition = observe_completed_step(taper, PARTIAL_TIGHT, 8, 115, 120)
	if String((transition.get("state", {}) as Dictionary).get("mode", "")) != ACTIVE_MODE:
		return _failure("R23D10_GJT_MUTATION_RESET_CONTACT")
	mutations += 1
	for observation in [
		{"contacts": SUPPORTED, "torso_tilt_rad": 0.04, "maximum_absolute_joint_position_error_rad": 0.18},
		{"contacts": SUPPORTED, "torso_tilt_rad": 0.005, "maximum_absolute_joint_position_error_rad": 0.33},
	]:
		transition = observe_completed_step(taper, observation, 8, 115, 120)
		if String((transition.get("state", {}) as Dictionary).get("mode", "")) != ACTIVE_MODE:
			return _failure("R23D10_GJT_MUTATION_RESET_POSE")
		mutations += 1
	if String(observe_completed_step(taper, TIGHT, 8, 114, 120).get("failure_code", "")) != "R23D10_VELOCITY_SCALE_MISMATCH":
		return _failure("R23D10_GJT_MUTATION_NUMERATOR")
	mutations += 1
	if String(observe_completed_step(taper, TIGHT, 8, 115, 119).get("failure_code", "")) != "R23D10_VELOCITY_SCALE_MISMATCH":
		return _failure("R23D10_GJT_MUTATION_DENOMINATOR")
	mutations += 1
	var early := initial_state()
	early["next_step"] = 100
	early["mode"] = TAPER_MODE
	early["taper_step_count"] = 118
	transition = observe_completed_step(early, TIGHT, 8, 2, 120)
	if String((transition.get("state", {}) as Dictionary).get("mode", "")) != TAPER_MODE:
		return _failure("R23D10_GJT_MUTATION_EARLY_HANDOFF")
	mutations += 1
	var near := initial_state()
	near["next_step"] = 200
	near["mode"] = TAPER_MODE
	near["taper_step_count"] = 119
	for observation in [
		{"contacts": SUPPORTED, "torso_tilt_rad": 0.02, "maximum_absolute_joint_position_error_rad": 0.18},
		{"contacts": SUPPORTED, "torso_tilt_rad": 0.005, "maximum_absolute_joint_position_error_rad": 0.25},
	]:
		transition = observe_completed_step(near, observation, 8, 1, 120)
		if String((transition.get("state", {}) as Dictionary).get("mode", "")) != TAPER_MODE:
			return _failure("R23D10_GJT_MUTATION_TIGHT_POSE")
		mutations += 1
	var deadline_state := initial_state()
	deadline_state["next_step"] = 539
	transition = observe_completed_step(deadline_state, PARTIAL_TIGHT, 8, 120, 120)
	if String((transition.get("state", {}) as Dictionary).get("mode", "")) != PASSIVE_MODE:
		return _failure("R23D10_GJT_MUTATION_DEADLINE")
	mutations += 1
	if bool(deadline.get("quiescent_taper_gate_passed", true)):
		return _failure("R23D10_GJT_MUTATION_FORCED_PASS")
	mutations += 1
	var passive := initial_state()
	passive["next_step"] = 600
	passive["mode"] = PASSIVE_MODE
	passive["confirmation_satisfied"] = true
	passive["handoff_after_active_step"] = 120
	passive["first_passive_step"] = 121
	passive["handoff_reason"] = CONFIRMED_REASON
	transition = observe_completed_step(passive, PARTIAL_TIGHT, 0, 0, 120)
	if String((transition.get("state", {}) as Dictionary).get("mode", "")) != PASSIVE_MODE:
		return _failure("R23D10_GJT_MUTATION_REACTIVATION")
	mutations += 1
	if String(observe_completed_step(passive, TIGHT, 8, 0, 120).get("failure_code", "")) != "R23D10_APPLICATION_COUNT_MISMATCH":
		return _failure("R23D10_GJT_MUTATION_PASSIVE_APPLICATION")
	mutations += 1
	var short := initial_state()
	short["next_step"] = 899
	if String(outcome(short).get("failure_code", "")) != "R23D10_OUTCOME_BEFORE_HORIZON":
		return _failure("R23D10_GJT_MUTATION_SHORT_HORIZON")
	mutations += 1
	if [COARSE_MAXIMUM_TILT_RAD, COARSE_MAXIMUM_JOINT_ERROR_RAD, TIGHT_MAXIMUM_TILT_RAD, TIGHT_MAXIMUM_JOINT_ERROR_RAD] != [0.035, 0.32, 0.01, 0.2]:
		return _failure("R23D10_GJT_MUTATION_THRESHOLDS")
	mutations += 1
	if [MINIMUM_TAPER_STEPS, MAXIMUM_ACTIVE_STEPS, MINIMUM_PASSIVE_STEPS, TERMINAL_STEPS] != [120, 540, 360, 900]:
		return _failure("R23D10_GJT_MUTATION_SCHEDULE")
	mutations += 1
	if mutations != 16:
		return _failure("R23D10_GJT_MUTATION_COUNT")
	return {
		"ok": true,
		"failure_code": "",
		"oracle_canary_count": 5,
		"mutation_control_count": mutations,
		"physical_process_launch_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_execution_authorized": false,
	}
