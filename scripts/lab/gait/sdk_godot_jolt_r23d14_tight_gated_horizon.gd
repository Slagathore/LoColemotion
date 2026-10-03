extends RefCounted

## Independent Godot/Jolt GDScript zero-world mirror of the frozen R23D14
## temporal policy. This source contains no physics world and does not preload
## the Python stage-zero reference oracle.

const GATE_ID := "QSDK-R23D14"
const CAMPAIGN_ID := (
	"QSDK-R23D14-TIGHT-GATED-HORIZON-THREE-ENGINE-TURN-CONFIRMATION"
)
const POLICY_ID := "sporespore_tight_gated_acquisition_active600_v1"
const ENGINE_ID := "godot_jolt"

const ACTIVE_MODE := "active_neutral_acquisition"
const TAPER_MODE := "active_quiescent_taper"
const PASSIVE_MODE := "irreversible_zero_actuation_stability"
const CONFIRMED_REASON := "support_pose_quiescence_confirmed"
const DEADLINE_REASON := "deadline_forced_without_quiescence_confirmation"

const TERMINAL_STEPS := 960
const MAXIMUM_ACTIVE_STEPS := 600
const MINIMUM_TAPER_STEPS := 120
const MINIMUM_PASSIVE_STEPS := 360
const ACTUATOR_COUNT := 8
const SCALE_DENOMINATOR := 120
const COARSE_MAXIMUM_TILT_RAD := 0.035
const COARSE_MAXIMUM_JOINT_ERROR_RAD := 0.32
const TIGHT_MAXIMUM_TILT_RAD := 0.01
const TIGHT_MAXIMUM_JOINT_ERROR_RAD := 0.2

const EXPECTED_MUTATION_CODES := [
	"R23D14_OBSERVATION_CONTACT_SHAPE_INVALID",
	"R23D14_OBSERVATION_CONTACT_SHAPE_INVALID",
	"R23D14_OBSERVATION_NUMERIC_TYPE_INVALID",
	"R23D14_OBSERVATION_NUMERIC_VALUE_INVALID",
	"R23D14_OBSERVATION_NUMERIC_VALUE_INVALID",
	"R23D14_STEP_OUTSIDE_HORIZON",
	"R23D14_STATE_MODE_INVALID",
	"R23D14_VELOCITY_SCALE_MISMATCH",
	"R23D14_VELOCITY_SCALE_MISMATCH",
	"R23D14_APPLICATION_COUNT_MISMATCH",
	"R23D14_APPLICATION_COUNT_MISMATCH",
	"R23D14_OBSERVATION_HORIZON_INVALID",
	"R23D14_OBSERVATION_HORIZON_INVALID",
	"R23D14_OUTCOME_BEFORE_TERMINAL_HORIZON",
]


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}


static func _state() -> Dictionary:
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


## Typed production reuse seam for the native temporal implementation.  The
## mutation-oriented helpers remain private; physical workers receive fresh
## state and a canonical tight observation without duplicating the law.
static func initial_state() -> Dictionary:
	return _state()


static func tight_observation() -> Dictionary:
	return _tight()


static func _observation(contacts: Array, tilt: Variant, joint_error: Variant) -> Dictionary:
	return {
		"contacts": contacts,
		"torso_tilt_rad": tilt,
		"maximum_absolute_joint_position_error_rad": joint_error,
	}


static func _tight() -> Dictionary:
	return _observation([true, true, true, true], 0.005, 0.1)


static func _coarse() -> Dictionary:
	return _observation([true, true, true, true], 0.02, 0.25)


static func _unsupported() -> Dictionary:
	return _observation([true, true, true, false], 0.005, 0.1)


static func _finite_number(value: Variant) -> bool:
	var kind := typeof(value)
	return (
		(kind == TYPE_INT or kind == TYPE_FLOAT) and
		is_finite(float(value))
	)


static func _observation_values(observation: Dictionary) -> Dictionary:
	var contacts: Variant = observation.get("contacts", null)
	if typeof(contacts) != TYPE_ARRAY or contacts.size() != 4:
		return _failure("R23D14_OBSERVATION_CONTACT_SHAPE_INVALID")
	var all_four := true
	for contact: Variant in contacts:
		if typeof(contact) != TYPE_BOOL:
			return _failure("R23D14_OBSERVATION_CONTACT_SHAPE_INVALID")
		all_four = all_four and bool(contact)
	var tilt: Variant = observation.get("torso_tilt_rad", null)
	var joint_error: Variant = observation.get(
		"maximum_absolute_joint_position_error_rad", null
	)
	if not _finite_number(tilt) or not _finite_number(joint_error):
		var numeric_type_valid: bool = (
			[TYPE_INT, TYPE_FLOAT].has(typeof(tilt)) and
			[TYPE_INT, TYPE_FLOAT].has(typeof(joint_error))
		)
		return _failure(
			"R23D14_OBSERVATION_NUMERIC_VALUE_INVALID"
			if numeric_type_valid
			else "R23D14_OBSERVATION_NUMERIC_TYPE_INVALID"
		)
	if float(tilt) < 0.0 or float(joint_error) < 0.0:
		return _failure("R23D14_OBSERVATION_NUMERIC_VALUE_INVALID")
	return {
		"ok": true,
		"all_four": all_four,
		"tilt": float(tilt),
		"joint_error": float(joint_error),
	}


static func expected_velocity_scale(state: Dictionary) -> Dictionary:
	var mode := String(state.get("mode", ""))
	if mode == ACTIVE_MODE:
		return {"ok": true, "numerator": 120, "denominator": 120}
	if mode == TAPER_MODE:
		return {
			"ok": true,
			"numerator": maxi(
				1, MINIMUM_TAPER_STEPS - int(state.get("taper_step_count", 0))
			),
			"denominator": 120,
		}
	if mode == PASSIVE_MODE:
		return {"ok": true, "numerator": 0, "denominator": 120}
	return _failure("R23D14_STATE_MODE_INVALID")


static func _handoff(state: Dictionary, step: int, confirmed: bool) -> Dictionary:
	var next := state.duplicate(true)
	next["mode"] = PASSIVE_MODE
	next["confirmation_satisfied"] = confirmed
	next["handoff_after_active_step"] = step
	next["first_passive_step"] = step + 1
	next["handoff_reason"] = CONFIRMED_REASON if confirmed else DEADLINE_REASON
	return next


static func observe_completed_step(
	state: Dictionary,
	observation: Dictionary,
	native_application_count: int,
	velocity_scale_numerator: int,
	velocity_scale_denominator: int
) -> Dictionary:
	var step := int(state.get("next_step", -1))
	if step < 0 or step >= TERMINAL_STEPS:
		return _failure("R23D14_STEP_OUTSIDE_HORIZON")
	var mode := String(state.get("mode", ""))
	if not [ACTIVE_MODE, TAPER_MODE, PASSIVE_MODE].has(mode):
		return _failure("R23D14_STATE_MODE_INVALID")
	var values := _observation_values(observation)
	if not bool(values.get("ok", false)):
		return values
	var scale := expected_velocity_scale(state)
	if (
		velocity_scale_numerator != int(scale.get("numerator", -1)) or
		velocity_scale_denominator != int(scale.get("denominator", -1))
	):
		return _failure("R23D14_VELOCITY_SCALE_MISMATCH")
	var expected_applications := 0 if mode == PASSIVE_MODE else ACTUATOR_COUNT
	if native_application_count != expected_applications:
		return _failure("R23D14_APPLICATION_COUNT_MISMATCH")

	var all_four := bool(values["all_four"])
	var tilt := float(values["tilt"])
	var joint_error := float(values["joint_error"])
	var coarse: bool = (
		all_four and tilt <= COARSE_MAXIMUM_TILT_RAD and
		joint_error <= COARSE_MAXIMUM_JOINT_ERROR_RAD
	)
	var tight: bool = (
		all_four and tilt <= TIGHT_MAXIMUM_TILT_RAD and
		joint_error <= TIGHT_MAXIMUM_JOINT_ERROR_RAD
	)
	var pre_taper_count := int(state.get("taper_step_count", 0))
	var transitioned := false
	var reset := false
	var next := state.duplicate(true)
	next["next_step"] = step + 1
	if mode == ACTIVE_MODE or mode == TAPER_MODE:
		next["active_step_count"] = int(state["active_step_count"]) + 1
		next["active_native_application_count"] = (
			int(state["active_native_application_count"]) + native_application_count
		)
		if mode == ACTIVE_MODE:
			if step == MAXIMUM_ACTIVE_STEPS - 1:
				next = _handoff(next, step, false)
				transitioned = true
			elif tight:
				next["mode"] = TAPER_MODE
				next["taper_step_count"] = 0
				transitioned = true
		elif tight:
			var post_taper_count := mini(
				MINIMUM_TAPER_STEPS, pre_taper_count + 1
			)
			next["taper_step_count"] = post_taper_count
			if post_taper_count >= MINIMUM_TAPER_STEPS:
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
		if not all_four:
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
			"all_four_contacts": all_four,
			"torso_tilt_rad": tilt,
			"maximum_absolute_joint_position_error_rad": joint_error,
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
		return _failure("R23D14_OUTCOME_BEFORE_TERMINAL_HORIZON")
	var first_passive: Variant = state.get("first_passive_step", null)
	var passed: bool = (
		bool(state["confirmation_satisfied"]) and
		String(state["handoff_reason"]) == CONFIRMED_REASON and
		first_passive != null and int(first_passive) <= MAXIMUM_ACTIVE_STEPS and
		int(state["passive_step_count"]) >= MINIMUM_PASSIVE_STEPS and
		int(state["passive_native_application_count"]) == 0 and
		int(state["post_handoff_contact_loss_step_count"]) == 0 and
		String(state["mode"]) == PASSIVE_MODE
	)
	var result := state.duplicate(true)
	result["ok"] = true
	result["quiescent_taper_gate_passed"] = passed
	return result


static func simulate(observations: Array) -> Dictionary:
	if observations.size() != TERMINAL_STEPS:
		return _failure("R23D14_OBSERVATION_HORIZON_INVALID")
	var state := _state()
	for observation: Dictionary in observations:
		var scale := expected_velocity_scale(state)
		var applications := 0 if String(state["mode"]) == PASSIVE_MODE else 8
		var step := observe_completed_step(
			state,
			observation,
			applications,
			int(scale["numerator"]),
			int(scale["denominator"])
		)
		if not bool(step.get("ok", false)):
			return step
		state = step["state"]
	return outcome(state)


static func _repeat(observation: Dictionary, count: int) -> Array:
	var rows: Array = []
	rows.resize(count)
	rows.fill(observation)
	return rows


static func _combined(
	first: Dictionary, first_count: int, second: Dictionary, second_count: int
) -> Array:
	var rows := _repeat(first, first_count)
	rows.append_array(_repeat(second, second_count))
	return rows


static func _bool_text(value: bool) -> String:
	return "true" if value else "false"


static func _semantic_context() -> Dictionary:
	var tight := _tight()
	var coarse := _coarse()
	var unsupported := _unsupported()
	var tight_step := observe_completed_step(_state(), tight, 8, 120, 120)
	var tight_state: Dictionary = tight_step["state"]
	var coarse_step := observe_completed_step(_state(), coarse, 8, 120, 120)
	var coarse_state: Dictionary = coarse_step["state"]
	var reset_step := observe_completed_step(tight_state, unsupported, 8, 120, 120)
	var reset_state: Dictionary = reset_step["state"]
	var positive := simulate(_combined(coarse, 318, tight, 642))
	var negative := simulate(_combined(coarse, 459, tight, 501))
	var deadline := simulate(_repeat(coarse, TERMINAL_STEPS))
	var earliest := simulate(_repeat(tight, TERMINAL_STEPS))
	var loss_rows := _repeat(tight, 121)
	loss_rows.append(unsupported)
	loss_rows.append_array(_repeat(tight, 838))
	var loss := simulate(loss_rows)
	var boundary_step := observe_completed_step(
		_state(), _observation([true, true, true, true], 0.01, 0.2), 8, 120, 120
	)
	var over_step := observe_completed_step(
		_state(),
		_observation([true, true, true, true], 0.010000000001, 0.2),
		8,
		120,
		120
	)
	var lines := PackedStringArray([
		"schedule|960|600|120|360",
		"tight_entry|%s|%d|120|120" % [
			String(tight_state["mode"]), int(tight_state["taper_step_count"]),
		],
		"coarse_hold|%s|120|120" % String(coarse_state["mode"]),
		"tight_loss_reset|%s|%d|120|120" % [
			String(reset_state["mode"]), int(reset_state["taper_reset_count"]),
		],
		"positive|438|439|521|%s" % _bool_text(
			bool(positive["quiescent_taper_gate_passed"])
		),
		"negative|579|580|380|%s" % _bool_text(
			bool(negative["quiescent_taper_gate_passed"])
		),
		"deadline|599|600|360|%s" % _bool_text(
			bool(deadline["quiescent_taper_gate_passed"])
		),
		"earliest|120|121|839|%s" % _bool_text(
			bool(earliest["quiescent_taper_gate_passed"])
		),
		"post_handoff_loss|120|121|1|121|%s" % _bool_text(
			bool(loss["quiescent_taper_gate_passed"])
		),
		"tight_boundary|%s|%s" % [
			String(boundary_step["state"]["mode"]),
			_bool_text(bool(boundary_step["receipt"]["tight_pose_satisfied"])),
		],
		"over_tight_boundary|%s|%s" % [
			String(over_step["state"]["mode"]),
			_bool_text(bool(over_step["receipt"]["tight_pose_satisfied"])),
		],
		"passive_zero|%d|0|%s" % [
			int(earliest["passive_native_application_count"]),
			String(earliest["mode"]),
		],
	])
	return {
		"vector": "\n".join(lines),
		"positive": positive,
		"negative": negative,
		"deadline": deadline,
		"earliest": earliest,
		"loss": loss,
		"reset_step": reset_step,
	}


static func _mutation_results() -> Array:
	var tight := _tight()
	var short_contacts := tight.duplicate(true)
	short_contacts["contacts"] = [true, true, true]
	var typed_contacts := tight.duplicate(true)
	typed_contacts["contacts"] = [true, true, true, 1]
	var typed_number := tight.duplicate(true)
	typed_number["torso_tilt_rad"] = "0.005"
	var nan_tilt := tight.duplicate(true)
	nan_tilt["torso_tilt_rad"] = NAN
	var negative_error := tight.duplicate(true)
	negative_error["maximum_absolute_joint_position_error_rad"] = -0.1
	var end_state := _state()
	end_state["next_step"] = TERMINAL_STEPS
	var invalid_mode := _state()
	invalid_mode["mode"] = "negative_heading_recovery"
	var passive := _state()
	passive["mode"] = PASSIVE_MODE
	var early_outcome := _state()
	early_outcome["next_step"] = TERMINAL_STEPS - 1
	return [
		observe_completed_step(_state(), short_contacts, 8, 120, 120),
		observe_completed_step(_state(), typed_contacts, 8, 120, 120),
		observe_completed_step(_state(), typed_number, 8, 120, 120),
		observe_completed_step(_state(), nan_tilt, 8, 120, 120),
		observe_completed_step(_state(), negative_error, 8, 120, 120),
		observe_completed_step(end_state, tight, 8, 120, 120),
		observe_completed_step(invalid_mode, tight, 8, 120, 120),
		observe_completed_step(_state(), tight, 8, 119, 120),
		observe_completed_step(_state(), tight, 8, 120, 119),
		observe_completed_step(_state(), tight, 0, 120, 120),
		observe_completed_step(passive, tight, 8, 0, 120),
		simulate(_repeat(tight, TERMINAL_STEPS - 1)),
		simulate(_repeat(tight, TERMINAL_STEPS + 1)),
		outcome(early_outcome),
	]


static func preflight() -> Dictionary:
	var context := _semantic_context()
	var mutation_codes: Array[String] = []
	for result: Dictionary in _mutation_results():
		if bool(result.get("ok", false)):
			return _failure("R23D14_MUTATION_UNEXPECTEDLY_ACCEPTED")
		mutation_codes.append(String(result.get("failure_code", "")))
	if mutation_codes != EXPECTED_MUTATION_CODES:
		return _failure("R23D14_MUTATION_FAILURE_CODES_CHANGED")
	var positive: Dictionary = context["positive"]
	var negative: Dictionary = context["negative"]
	var earliest: Dictionary = context["earliest"]
	var retained_positive: bool = (
		int(positive["handoff_after_active_step"]) == 438 and
		int(positive["first_passive_step"]) == 439 and
		int(positive["passive_step_count"]) == 521 and
		bool(positive["quiescent_taper_gate_passed"])
	)
	var retained_negative: bool = (
		int(negative["handoff_after_active_step"]) == 579 and
		int(negative["first_passive_step"]) == 580 and
		int(negative["passive_step_count"]) == 380 and
		bool(negative["quiescent_taper_gate_passed"])
	)
	var passive_zero: bool = (
		int(earliest["passive_native_application_count"]) == 0 and
		String(earliest["mode"]) == PASSIVE_MODE and
		bool(earliest["quiescent_taper_gate_passed"])
	)
	if not (retained_positive and retained_negative and passive_zero):
		return _failure("R23D14_NATIVE_CANARY_FAILED")
	return {
		"ok": true,
		"schema_version": "sporespore_qsdk_r23d14_native_temporal_preflight_v1",
		"gate_id": GATE_ID,
		"campaign_id": CAMPAIGN_ID,
		"policy_id": POLICY_ID,
		"engine_id": ENGINE_ID,
		"language": "gdscript",
		"valid_canary_count": 12,
		"mutation_control_count": mutation_codes.size(),
		"valid_canary_vector": String(context["vector"]),
		"mutation_failure_codes": mutation_codes,
		"retained_positive_timing_shape_passed": retained_positive,
		"retained_negative_timing_shape_passed": retained_negative,
		"passive_exact_zero_actuation_canary_passed": passive_zero,
		"reference_oracle_imported": false,
		"physical_worker_implemented": false,
		"physical_execution_authorized": false,
		"physical_process_launch_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}
