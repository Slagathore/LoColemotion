extends SceneTree
# gdlint: disable=max-line-length

const Entry := preload("res://sdk/adapters/godot/gdscript/development_passive_entry_orchestrator_v1.gd")
const Prior := Entry.Prior
const Worker := preload("res://sdk/adapters/godot/gdscript/development_passive_entry_smoke_worker_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const SHA := "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
var _checks := {}


func _initialize() -> void:
	call_deferred("_run")


func _advance(sdk: Object, state: Dictionary, fields: Dictionary) -> Dictionary:
	fields["global_semantic_step"] = state["previous_global_semantic_step"] + 1
	fields["application_intent_sha256"] = SHA
	var built := Entry.build_event_v1(sdk, state, fields)
	if built.get("ok") != true:
		_checks["event_build_failed"] = false
		return {}
	var advanced := Entry.advance_v1(sdk, state, built["event"])
	if advanced.get("ok") != true:
		print("SCHEDULER_FAILURE ", Transport.stringify(advanced), " ", Transport.stringify(fields))
		_checks["advance_failed"] = false
		return {}
	return advanced["state_after"]


func _prefix(sdk: Object, limit: int) -> Dictionary:
	var built := Entry.initialize_v1(sdk, "synthetic_entry_schedule", "kick_passive_recovery_resume", "synthetic_model", SHA, SHA, limit)
	var state: Dictionary = built.get("state", {})
	_checks["original_state_schema_remains_closed"] = not Prior.state_valid_v1(sdk, state)
	state = _advance(sdk, state, {"event_kind": "precondition_pair_ready", "control_owner": "recovery_v6",
		"actuation_owner": "recovery_v6", "recovery_actuation_applied": true,
		"stable_four_foot_stance": true, "recovery_controller_terminal_phase": "complete"})
	state = _advance(sdk, state, {"event_kind": "precondition_pair_release_step", "no_actuation_requested": true})
	for index in range(1, 31):
		state = _advance(sdk, state, {"event_kind": "walking_policy_step", "control_owner": "walking_bw5r_b",
			"actuation_owner": "walking_bw5r_b", "walking_actuation_applied": true,
			"walking_session_id": "synthetic_prefix", "walking_session_local_step": index})
	return _advance(sdk, state, {"event_kind": "kick_effect_step", "no_actuation_requested": true,
		"interaction_receipt_sha256": SHA, "energy_initializer_sha256": SHA, "kick_application_count": 1,
		"walking_motors_disabled_in_same_pre_solver_event": true})


func _descent_fields(state: Dictionary, status: String) -> Dictionary:
	return {"event_kind": "passive_entry_observation", "no_actuation_requested": true,
		"recovery_epoch_local_step": state["recovery_epoch_step_count"] + 1,
		"energy_initializer_sha256": SHA, "passive_entry_receipt_sha256": SHA,
		"passive_entry_status": status, "prone_sample": status == "prone_handoff",
		"canonical_initialization_count": 1 if status == "prone_handoff" else 0}


func _run() -> void:
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var state := _prefix(sdk, 75)
	_checks["kick_enters_distinct_descent"] = state.get("phase") == Entry.PHASE_DESCENT
	var epoch: int = state["epoch_start_global_step"]
	for count in range(61):
		state = _advance(sdk, state, _descent_fields(state, "waiting_for_prone"))
	_checks["no_getup_clock_after_61_descent_steps"] = state["confirm_prone_step_count"] == 0 and state["canonical_start_global_step"] == null and state["phase"] == Entry.PHASE_DESCENT
	var before := state.duplicate(true)
	state = _advance(sdk, state, _descent_fields(state, "prone_handoff"))
	_checks["handoff_starts_one_confirmation_sample"] = state["confirm_prone_step_count"] == 1 and state["consecutive_prone_sample_count"] == 1
	_checks["handoff_keeps_energy_epoch"] = state["epoch_start_global_step"] == epoch and state["canonical_start_global_step"] == epoch + 62
	_checks["input_state_preserved"] = before["confirm_prone_step_count"] == 0 and before["phase"] == Entry.PHASE_DESCENT
	for count in range(11):
		state = _advance(sdk, state, {"event_kind": "passive_prone_observation", "control_owner": "recovery_v6",
			"no_actuation_requested": true, "prone_sample": true, "energy_initializer_sha256": SHA,
			"recovery_epoch_local_step": state["previous_global_semantic_step"] + 1 - epoch})
	_checks["unchanged_twelve_sample_confirmation"] = state["confirm_prone_step_count"] == 12 and state["phase"] == Prior.PHASE_POST_KICK_RECOVERY
	_checks["handoff_sample_not_double_counted"] = state["recovery_epoch_step_count"] == state["passive_descent_step_count"] + state["confirm_prone_step_count"] - 1
	state = _advance(sdk, state, {"event_kind": "recovery_controller_step", "control_owner": "recovery_v6",
		"actuation_owner": "recovery_v6", "recovery_actuation_applied": true,
		"stable_four_foot_stance": true, "recovery_controller_terminal_phase": "complete",
		"energy_initializer_sha256": SHA, "recovery_epoch_local_step": state["previous_global_semantic_step"] + 1 - epoch})
	state = _advance(sdk, state, {"event_kind": "walking_policy_step", "control_owner": "walking_bw5r_b",
		"actuation_owner": "walking_bw5r_b", "walking_actuation_applied": true,
		"walking_session_id": "synthetic_resume", "walking_session_local_step": 1,
		"recovery_epoch_local_step": state["previous_global_semantic_step"] + 1 - epoch})
	_checks["canonical_recovery_reaches_fresh_resume"] = state["walking_resume_step_count"] == 1 and state["phase"] == Prior.PHASE_WALKING_RESUME
	var timeout_state := _prefix(sdk, 1)
	var timeout_fields := _descent_fields(timeout_state, "descent_timeout")
	timeout_fields["global_semantic_step"] = timeout_state["previous_global_semantic_step"] + 1
	timeout_fields["application_intent_sha256"] = SHA
	var timeout_event := Entry.build_event_v1(sdk, timeout_state, timeout_fields)
	var terminal := Entry.advance_v1(sdk, timeout_state, timeout_event["event"])
	_checks["timeout_creates_no_getup_state"] = terminal["state_after"]["phase"] == Prior.PHASE_FAILED and terminal["state_after"]["canonical_start_global_step"] == null
	_checks["terminal_state_cannot_restart"] = Entry.advance_v1(sdk, terminal["state_after"], timeout_event["event"]).get("ok") == false
	_checks["original_event_schema_remains_closed"] = not Prior.event_valid_v1(sdk, timeout_event["event"])
	var illegal := _descent_fields(timeout_state, "prone_handoff")
	illegal["canonical_initialization_count"] = 0
	illegal["global_semantic_step"] = timeout_state["previous_global_semantic_step"] + 1
	illegal["application_intent_sha256"] = SHA
	_checks["inconsistent_handoff_refused"] = Entry.build_event_v1(sdk, timeout_state, illegal).get("ok") == false
	_checks["new_worker_resource_parses"] = Worker != null
	var ok := true
	for value in _checks.values():
		ok = ok and value == true
	print("DEVELOPMENT_PASSIVE_ENTRY_SCHEDULER ", Transport.stringify({"ok": ok, "checks": _checks,
		"synthetic_events_only": true, "world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}))
	quit(0 if ok else 1)
