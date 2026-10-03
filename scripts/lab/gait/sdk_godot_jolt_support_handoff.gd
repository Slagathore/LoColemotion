extends RefCounted

## Independent zero-world Godot mirror of the frozen R23D9 temporal policy.

const TERMINAL_STEPS := 780
const MAXIMUM_ACTIVE_STEPS := 420
const SUPPORT_CONFIRMATION_STEPS := 30
const MINIMUM_PASSIVE_STEPS := 360
const ACTUATOR_COUNT := 8
const ACTIVE_MODE := "active_neutral_acquisition"
const PASSIVE_MODE := "irreversible_zero_actuation_stability"
const SUPPORT_REASON := "support_confirmed"
const DEADLINE_REASON := "deadline_forced_without_support_confirmation"


static func initial_state() -> Dictionary:
	return {
		"next_step": 0,
		"mode": ACTIVE_MODE,
		"support_counter": 0,
		"handoff_after_active_step": null,
		"first_passive_step": null,
		"handoff_reason": null,
		"support_confirmed": false,
		"active_step_count": 0,
		"passive_step_count": 0,
		"active_native_application_count": 0,
		"passive_native_application_count": 0,
		"first_post_handoff_contact_loss_step": null,
		"post_handoff_contact_loss_step_count": 0,
	}


static func observe_completed_step(
	state: Dictionary,
	contacts: Array,
	native_application_count: int
) -> Dictionary:
	if (
		int(state.get("next_step", -1)) < 0
		or int(state.get("next_step", -1)) >= TERMINAL_STEPS
		or contacts.size() != 4
	):
		return _failure("R23D9_GJT_STEP_OR_CONTACT_SHAPE_INVALID")
	for present: Variant in contacts:
		if typeof(present) != TYPE_BOOL:
			return _failure("R23D9_GJT_CONTACT_TYPE_INVALID")
	var active := String(state.get("mode", "")) == ACTIVE_MODE
	if not active and String(state.get("mode", "")) != PASSIVE_MODE:
		return _failure("R23D9_GJT_MODE_INVALID")
	var expected_applications := ACTUATOR_COUNT if active else 0
	if native_application_count != expected_applications:
		return _failure("R23D9_GJT_APPLICATION_COUNT_MISMATCH")
	var all_four := true
	for present: bool in contacts:
		all_four = all_four and present
	var next := state.duplicate(true)
	var step := int(state["next_step"])
	var pre_counter := int(state["support_counter"])
	var post_counter := pre_counter
	var transitioned := false
	next["next_step"] = step + 1
	if active:
		next["active_step_count"] = int(state["active_step_count"]) + 1
		next["active_native_application_count"] = (
			int(state["active_native_application_count"]) + native_application_count
		)
		post_counter = pre_counter + 1 if all_four else 0
		next["support_counter"] = post_counter
		if post_counter >= SUPPORT_CONFIRMATION_STEPS:
			next["mode"] = PASSIVE_MODE
			next["handoff_after_active_step"] = step
			next["first_passive_step"] = step + 1
			next["handoff_reason"] = SUPPORT_REASON
			next["support_confirmed"] = true
			transitioned = true
		elif step == MAXIMUM_ACTIVE_STEPS - 1:
			next["mode"] = PASSIVE_MODE
			next["handoff_after_active_step"] = step
			next["first_passive_step"] = step + 1
			next["handoff_reason"] = DEADLINE_REASON
			next["support_confirmed"] = false
			transitioned = true
		elif step >= MAXIMUM_ACTIVE_STEPS:
			return _failure("R23D9_GJT_ACTIVE_AFTER_DEADLINE")
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
	var receipt := {
		"step": step,
		"mode": String(state["mode"]),
		"all_four_contacts": all_four,
		"pre_step_support_counter": pre_counter,
		"post_step_support_counter": post_counter,
		"native_application_count": native_application_count,
		"transition_after_step": transitioned,
		"next_mode": String(next["mode"]),
		"handoff_reason": next["handoff_reason"] if transitioned else null,
	}
	return {"ok": true, "state": next, "receipt": receipt}


static func outcome(state: Dictionary) -> Dictionary:
	if int(state.get("next_step", -1)) != TERMINAL_STEPS:
		return _failure("R23D9_GJT_OUTCOME_BEFORE_HORIZON")
	var first_passive: Variant = state["first_passive_step"]
	var passed := (
		bool(state["support_confirmed"])
		and String(state["handoff_reason"]) == SUPPORT_REASON
		and first_passive != null
		and int(first_passive) >= SUPPORT_CONFIRMATION_STEPS
		and int(first_passive) <= MAXIMUM_ACTIVE_STEPS
		and int(state["passive_step_count"]) >= MINIMUM_PASSIVE_STEPS
		and int(state["passive_native_application_count"]) == 0
		and int(state["post_handoff_contact_loss_step_count"]) == 0
		and String(state["mode"]) == PASSIVE_MODE
	)
	return {
		"terminal_step_count": int(state["next_step"]),
		"handoff_after_active_step": state["handoff_after_active_step"],
		"first_passive_step": first_passive,
		"handoff_reason": state["handoff_reason"],
		"support_confirmed": bool(state["support_confirmed"]),
		"active_step_count": int(state["active_step_count"]),
		"passive_step_count": int(state["passive_step_count"]),
		"active_native_application_count": int(
			state["active_native_application_count"]
		),
		"passive_native_application_count": int(
			state["passive_native_application_count"]
		),
		"first_post_handoff_contact_loss_step": (
			state["first_post_handoff_contact_loss_step"]
		),
		"post_handoff_contact_loss_step_count": int(
			state["post_handoff_contact_loss_step_count"]
		),
		"irreversible_handoff_gate_passed": passed,
	}


static func simulate(contact_rows: Array) -> Dictionary:
	if contact_rows.size() != TERMINAL_STEPS:
		return _failure("R23D9_GJT_CONTACT_HORIZON_INVALID")
	var state := initial_state()
	var receipts: Array[Dictionary] = []
	for contacts: Array in contact_rows:
		var applications := (
			ACTUATOR_COUNT if String(state["mode"]) == ACTIVE_MODE else 0
		)
		var observed := observe_completed_step(state, contacts, applications)
		if not bool(observed.get("ok", false)):
			return observed
		state = (observed["state"] as Dictionary).duplicate(true)
		receipts.append((observed["receipt"] as Dictionary).duplicate(true))
	var final_outcome := outcome(state)
	if final_outcome.has("failure_code"):
		return final_outcome
	return {
		"ok": true,
		"receipts": receipts,
		"outcome": final_outcome,
	}


static func validate_replay(
	contact_rows: Array,
	receipts: Array,
	reported_outcome: Dictionary
) -> bool:
	var expected := simulate(contact_rows)
	return (
		bool(expected.get("ok", false))
		and receipts.size() == TERMINAL_STEPS
		and JSON.stringify(receipts) == JSON.stringify(expected["receipts"])
		and JSON.stringify(reported_outcome) == JSON.stringify(expected["outcome"])
	)


static func run_zero_world_preflight() -> Dictionary:
	var down := [false, false, false, false]
	var partial := [true, true, true, false]
	var supported := [true, true, true, true]
	var cases := [
		{
			"id": "support_from_first_step",
			"rows": _rows([[780, supported]]),
			"after": 29, "first": 30, "passed": true, "passive": 750, "losses": 0,
		},
		{
			"id": "predecessor_shaped_transients",
			"rows": _rows([
				[100, down], [23, supported], [1, partial], [16, supported],
				[1, partial], [159, down], [480, supported],
			]),
			"after": 329, "first": 330, "passed": true, "passive": 450, "losses": 0,
		},
		{
			"id": "confirmation_at_deadline",
			"rows": _rows([[390, down], [390, supported]]),
			"after": 419, "first": 420, "passed": true, "passive": 360, "losses": 0,
		},
		{
			"id": "never_confirmed",
			"rows": _rows([[780, down]]),
			"after": 419, "first": 420, "passed": false, "passive": 360, "losses": 360,
		},
		{
			"id": "post_handoff_contact_loss",
			"rows": _rows([[30, supported], [10, supported], [1, partial], [739, supported]]),
			"after": 29, "first": 30, "passed": false, "passive": 750, "losses": 1,
		},
	]
	var canary_outcomes := {}
	for canary: Dictionary in cases:
		var simulation := simulate(canary["rows"])
		var observed: Dictionary = simulation.get("outcome", {})
		if (
			not bool(simulation.get("ok", false))
			or not validate_replay(
				canary["rows"], simulation["receipts"], observed
			)
			or observed["handoff_after_active_step"] != canary["after"]
			or observed["first_passive_step"] != canary["first"]
			or observed["irreversible_handoff_gate_passed"] != canary["passed"]
			or observed["passive_step_count"] != canary["passive"]
			or observed["post_handoff_contact_loss_step_count"] != canary["losses"]
		):
			return _failure("R23D9_GJT_CANARY_FAILED:%s" % canary["id"])
		canary_outcomes[canary["id"]] = observed.duplicate(true)
	var mutation_count := _mutation_rejection_count(
		(cases[1] as Dictionary)["rows"]
	)
	if mutation_count != 12:
		return _failure("R23D9_GJT_MUTATION_ESCAPED")
	return {
		"schema_version": "sporespore_qsdk_r23d9_godot_handoff_preflight_v1",
		"ok": true,
		"failure_code": "",
		"oracle_canary_count": canary_outcomes.size(),
		"mutation_control_count": mutation_count,
		"oracle_canary_outcomes": canary_outcomes,
		"terminal_step_count": TERMINAL_STEPS,
		"maximum_active_step_count": MAXIMUM_ACTIVE_STEPS,
		"support_confirmation_step_count": SUPPORT_CONFIRMATION_STEPS,
		"minimum_passive_step_count": MINIMUM_PASSIVE_STEPS,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _mutation_rejection_count(sequence: Array) -> int:
	var baseline := simulate(sequence)
	if not bool(baseline.get("ok", false)):
		return -1
	var receipts: Array = baseline["receipts"]
	var observed: Dictionary = baseline["outcome"]
	var cases: Array[Dictionary] = []
	cases.append(_receipt_mutation(receipts, observed, 100, "transition_after_step", true))
	cases.append(_receipt_mutation(receipts, observed, 328, "transition_after_step", true))
	cases.append(_receipt_mutation(receipts, observed, 123, "post_step_support_counter", 23))
	cases.append(_receipt_mutation(receipts, observed, 123, "all_four_contacts", true))
	cases.append(_receipt_mutation(receipts, observed, 329, "mode", PASSIVE_MODE))
	cases.append(_receipt_mutation(receipts, observed, 400, "mode", ACTIVE_MODE))
	cases.append(_receipt_mutation(
		receipts, observed, 400, "native_application_count", ACTUATOR_COUNT
	))
	var early_outcome := observed.duplicate(true)
	early_outcome["handoff_after_active_step"] = 418
	early_outcome["first_passive_step"] = 419
	cases.append({"receipts": receipts.duplicate(true), "outcome": early_outcome})
	cases.append(_receipt_mutation(receipts, observed, 420, "mode", ACTIVE_MODE))
	var forced_pass := observed.duplicate(true)
	forced_pass["handoff_reason"] = DEADLINE_REASON
	forced_pass["support_confirmed"] = false
	forced_pass["irreversible_handoff_gate_passed"] = true
	cases.append({"receipts": receipts.duplicate(true), "outcome": forced_pass})
	var shortened: Array = receipts.duplicate(true)
	shortened.pop_back()
	cases.append({"receipts": shortened, "outcome": observed.duplicate(true)})
	var changed_horizon := observed.duplicate(true)
	changed_horizon["terminal_step_count"] = 779
	cases.append({"receipts": receipts.duplicate(true), "outcome": changed_horizon})
	var rejected := 0
	for mutation: Dictionary in cases:
		if not validate_replay(sequence, mutation["receipts"], mutation["outcome"]):
			rejected += 1
	return rejected


static func _receipt_mutation(
	receipts: Array,
	observed: Dictionary,
	index: int,
	key: String,
	value: Variant
) -> Dictionary:
	var changed: Array = receipts.duplicate(true)
	changed[index][key] = value
	return {"receipts": changed, "outcome": observed.duplicate(true)}


static func _rows(segments: Array) -> Array:
	var result: Array = []
	for segment: Array in segments:
		for _index in range(int(segment[0])):
			result.append((segment[1] as Array).duplicate())
	return result


static func _failure(code: String) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r23d9_godot_handoff_preflight_v1",
		"ok": false,
		"failure_code": code,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
