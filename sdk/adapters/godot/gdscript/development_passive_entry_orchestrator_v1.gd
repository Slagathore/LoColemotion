extends RefCounted
# gdlint: disable=max-line-length

## Distinct development state machine. Reuses the original phase kernels but
## does not run the canonical confirmation clock while the creature descends.
const Prior := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_event_triggered_passive_recovery_orchestrator_v1.gd")
const ORCHESTRATOR_ID := "sporespore_development_measured_prone_entry_orchestrator_v1"
const STATE_SCHEMA := "sporespore_development_measured_prone_entry_state_v1"
const EVENT_SCHEMA := "sporespore_development_measured_prone_entry_event_v1"
const PHASE_DESCENT := "controller_free_descent_to_measured_prone"
const STATE_EXTRA := ["passive_descent_step_count", "maximum_passive_descent_steps", "canonical_start_global_step"]
const EVENT_EXTRA := ["passive_entry_receipt_sha256", "passive_entry_status", "canonical_initialization_count"]
const StanceEntry := preload("res://sdk/adapters/godot/gdscript/recovery_stance_entry_route_v1.gd")
const PREFIX_STEPS := 30
const Owner := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_canonical_ownership_v1.gd")
const WalkingPolicy := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_policy_v1.gd")


static func schema_v1(original: String, controller_id: String) -> String:
	if controller_id == Owner.RATE_LIMITED_CONTROLLER_ID:
		return original.replace("measured_prone_entry", "rate_limited_recovery_entry")
	if controller_id == Owner.RECOVERY_CONTROLLER_ID:
		return original
	if controller_id == Owner.REARWARD_CONTROLLER_ID:
		return original.replace("measured_prone_entry", "rearward_fold_entry")
	if Owner.candidate_id_valid_v1(controller_id):
		return original.replace("measured_prone_entry", "candidate_" + controller_id + "_entry")
	return ""


static func _schema_for_route_v1(original: String, controller_id: String, route: String) -> String:
	var old := schema_v1(original, controller_id)
	if StanceEntry.hold_selected_v1(route) and not old.is_empty(): return old + "_r10j"
	return old + "_r10i" if StanceEntry.flexed_selected_v1(route) and not old.is_empty() else old + "_r10h" if StanceEntry.selected_v1(route) and not old.is_empty() else old

static func _state_keys_v1(route: String) -> Array:
	return Prior.STATE_KEYS + STATE_EXTRA + (StanceEntry.initial_fields_for_v1(route).keys() if StanceEntry.selected_v1(route) else [])

static func _event_keys_v1(route: String) -> Array:
	return Prior.EVENT_KEYS + EVENT_EXTRA + (["neutral_entry_readiness_sha256", "neutral_entry_ready"] if StanceEntry.selected_v1(route) else [])

static func owner_for_phase_v1(phase: String, controller_id: String) -> String:
	var selected := Owner.profile_v1(controller_id)
	if selected.is_empty():
		return ""
	return "recovery_v6" if phase == Prior.PHASE_PRECONDITION_RECOVERY else String(selected["owner"])


static func initialize_v1(sdk: Object, attempt: String, arm: String, model: String,
	configuration: String, population: String, maximum_descent_steps: int,
	controller_id: String = Owner.RECOVERY_CONTROLLER_ID, walking_policy_id: String = "") -> Dictionary:
	# Fresh zero-step template only, never conversion of an observed V1 state.
	var result := Prior.initialize_v1(sdk, attempt, arm, model, configuration, population)
	if result.get("ok") != true:
		return result
	var state: Dictionary = result["state"]
	state["schema_version"] = _schema_for_route_v1(STATE_SCHEMA, controller_id, walking_policy_id)
	state["orchestrator_id"] = _schema_for_route_v1(ORCHESTRATOR_ID, controller_id, walking_policy_id)
	state["passive_descent_step_count"] = 0
	state["maximum_passive_descent_steps"] = maximum_descent_steps
	state["canonical_start_global_step"] = null
	if StanceEntry.selected_v1(walking_policy_id): state.merge(StanceEntry.initial_fields_for_v1(walking_policy_id))
	state["payload_sha256"] = Prior._payload_sha256_v1(sdk, state)
	if not state_valid_v1(sdk, state, controller_id, walking_policy_id):
		return _failure("PASSIVE_ORCHESTRATOR_INITIAL_STATE_INVALID")
	result["schema_version"] = _schema_for_route_v1("sporespore_development_measured_prone_entry_initialization_v1", controller_id, walking_policy_id)
	return result


static func state_valid_v1(sdk: Object, state: Dictionary,
	controller_id: String = Owner.RECOVERY_CONTROLLER_ID, walking_policy_id: String = "") -> bool:
	if Owner.profile_v1(controller_id).is_empty():
		return false
	if not Prior._state_valid_shape_v1(sdk, state, _state_keys_v1(walking_policy_id),
		_schema_for_route_v1(STATE_SCHEMA, controller_id, walking_policy_id), _schema_for_route_v1(ORCHESTRATOR_ID, controller_id, walking_policy_id),
		[PHASE_DESCENT, StanceEntry.PHASE] if StanceEntry.selected_v1(walking_policy_id) else [PHASE_DESCENT],
		[PHASE_DESCENT, StanceEntry.PHASE] if StanceEntry.selected_v1(walking_policy_id) else [PHASE_DESCENT]):
		return false
	if StanceEntry.selected_v1(walking_policy_id) and not StanceEntry.state_fields_valid_for_v1(state, walking_policy_id): return false
	var count: Variant = state["passive_descent_step_count"]
	var limit: Variant = state["maximum_passive_descent_steps"]
	var start: Variant = state["canonical_start_global_step"]
	if typeof(count) != TYPE_INT or typeof(limit) != TYPE_INT or count < 0 or limit < 1 or limit > 1200 or count > limit:
		return false
	var phase: String = state["phase"]
	if state["arm_id"] == Prior.EnergyInitializer.BASELINE_ARM_ID:
		return (count == 0 and start == null
			and (phase == StanceEntry.PHASE and StanceEntry.selected_v1(walking_policy_id) or phase in [Prior.PHASE_PRECONDITION_RECOVERY, Prior.PHASE_WALKING_PREFIX,
				Prior.PHASE_INTERACTION, Prior.PHASE_MATCHED_CONTINUATION,
				Prior.PHASE_COMPLETE, Prior.PHASE_FAILED])
			and state["confirm_prone_step_count"] == 0
			and state["post_kick_recovery_step_count"] == 0
			and state["walking_resume_step_count"] == 0)
	if start != null:
		if (typeof(start) != TYPE_INT or count < 1
			or typeof(state["epoch_start_global_step"]) != TYPE_INT
			or start != state["epoch_start_global_step"] + count
			or start > state["previous_global_semantic_step"]
			or state["confirm_prone_step_count"] < 1 or phase == PHASE_DESCENT):
			return false
	elif state["confirm_prone_step_count"] != 0 or state["post_kick_recovery_step_count"] != 0 or state["walking_resume_step_count"] != 0:
		return false
	if phase == PHASE_DESCENT:
		return (start == null and count < limit
			and count == state["recovery_epoch_step_count"]
			and count == state["previous_global_semantic_step"] - state["epoch_start_global_step"])
	if phase in [Prior.PHASE_CONFIRM_PRONE, Prior.PHASE_POST_KICK_RECOVERY, Prior.PHASE_WALKING_RESUME, Prior.PHASE_COMPLETE] and start == null:
		return false
	if phase in [Prior.PHASE_PRECONDITION_RECOVERY, Prior.PHASE_WALKING_PREFIX, Prior.PHASE_INTERACTION] and (count != 0 or start != null):
		return false
	return true


static func build_event_v1(sdk: Object, state: Dictionary, fields: Dictionary,
	controller_id: String = Owner.RECOVERY_CONTROLLER_ID, walking_policy_id: String = "") -> Dictionary:
	if not state_valid_v1(sdk, state, controller_id, walking_policy_id):
		return _failure("PASSIVE_ORCHESTRATOR_EVENT_STATE_INVALID")
	var extra := {"passive_entry_receipt_sha256": fields.get("passive_entry_receipt_sha256", ""),
		"passive_entry_status": fields.get("passive_entry_status", ""),
		"canonical_initialization_count": fields.get("canonical_initialization_count", 0)}
	if StanceEntry.selected_v1(walking_policy_id):
		extra.merge({"neutral_entry_readiness_sha256": fields.get("neutral_entry_readiness_sha256", ""), "neutral_entry_ready": fields.get("neutral_entry_ready", false)})
	var result := Prior._build_event_for_shape_v1(sdk, state, fields, _schema_for_route_v1(EVENT_SCHEMA, controller_id, walking_policy_id),
		_schema_for_route_v1(ORCHESTRATOR_ID, controller_id, walking_policy_id), _event_keys_v1(walking_policy_id), extra,
		owner_for_phase_v1(state["phase"], controller_id), WalkingPolicy.owner_for_phase_v1(state["phase"], walking_policy_id))
	if result.get("ok") != true or not event_valid_v1(sdk, result["event"], controller_id, walking_policy_id):
		return _failure("PASSIVE_ORCHESTRATOR_EVENT_INVALID")
	result["schema_version"] = _schema_for_route_v1("sporespore_development_measured_prone_entry_event_build_v1", controller_id, walking_policy_id)
	return result


static func event_valid_v1(sdk: Object, event: Dictionary,
	controller_id: String = Owner.RECOVERY_CONTROLLER_ID, walking_policy_id: String = "") -> bool:
	if not Prior._event_valid_shape_v1(sdk, event, _event_keys_v1(walking_policy_id),
		_schema_for_route_v1(EVENT_SCHEMA, controller_id, walking_policy_id), _schema_for_route_v1(ORCHESTRATOR_ID, controller_id, walking_policy_id),
		owner_for_phase_v1(String(event.get("source_phase", "")), controller_id),
		WalkingPolicy.owner_for_phase_v1(String(event.get("source_phase", "")), walking_policy_id)):
		return false
	if StanceEntry.selected_v1(walking_policy_id):
		if typeof(event.get("neutral_entry_ready")) != TYPE_BOOL: return false
		if event.get("source_phase") == StanceEntry.PHASE:
			if not Prior._digest_valid_v1(event.get("neutral_entry_readiness_sha256", "")): return false
		elif event.get("neutral_entry_readiness_sha256") != "" or event.neutral_entry_ready: return false
	var status: Variant = event["passive_entry_status"]
	var count: Variant = event["canonical_initialization_count"]
	if typeof(status) != TYPE_STRING or typeof(count) != TYPE_INT:
		return false
	if event["source_phase"] != PHASE_DESCENT:
		return status == "" and count == 0 and event["passive_entry_receipt_sha256"] == ""
	return (status in ["waiting_for_prone", "prone_handoff", "descent_timeout"]
		and count == (1 if status == "prone_handoff" else 0)
		and bool(event["prone_sample"]) == (status == "prone_handoff")
		and Prior._digest_valid_v1(String(event["passive_entry_receipt_sha256"])))


static func advance_v1(sdk: Object, state: Dictionary, event: Dictionary,
	controller_id: String = Owner.RECOVERY_CONTROLLER_ID, walking_policy_id: String = "") -> Dictionary:
	if not state_valid_v1(sdk, state, controller_id, walking_policy_id) or not event_valid_v1(sdk, event, controller_id, walking_policy_id):
		return _failure("PASSIVE_ORCHESTRATOR_STATE_OR_EVENT_INVALID")
	var phase: String = state["phase"]
	if phase in [Prior.PHASE_COMPLETE, Prior.PHASE_FAILED]:
		return _failure("PASSIVE_ORCHESTRATOR_ALREADY_TERMINAL")
	for key in ["orchestrator_id", "attempt_id", "arm_id", "model_instance_id",
		"frozen_configuration_sha256", "body_population_instance_sha256", "ordered_same_body_node_ids"]:
		if state[key] != event[key]:
			return _failure("PASSIVE_ORCHESTRATOR_IDENTITY_CROSSED:" + key)
	if event["source_phase"] != phase or event["global_semantic_step"] != state["previous_global_semantic_step"] + 1:
		return _failure("PASSIVE_ORCHESTRATOR_SEQUENCE_CROSSED")
	for key in ["body_population_rebuild_count", "body_transform_write_count", "body_velocity_write_count", "solver_reset_count"]:
		if event[key] != 0:
			return _failure("PASSIVE_ORCHESTRATOR_FORBIDDEN_MUTATION:" + key)
	var successor := state.duplicate(true)
	successor["previous_global_semantic_step"] = event["global_semantic_step"]
	successor["total_completed_solver_step_count"] += 1
	successor["state_revision"] += 1
	var failure := ""
	match phase:
		Prior.PHASE_PRECONDITION_RECOVERY:
			failure = Prior._advance_precondition_v1(successor, event)
		Prior.PHASE_WALKING_PREFIX:
			failure = Prior._advance_walking_prefix_v1(successor, event, PREFIX_STEPS)
		Prior.PHASE_INTERACTION:
			failure = Prior._advance_interaction_v1(successor, event)
			if failure == "" and state["arm_id"] == Prior.EnergyInitializer.ACTIVE_ARM_ID:
				successor["phase"] = PHASE_DESCENT
			elif failure == "" and StanceEntry.selected_v1(walking_policy_id):
				successor["phase"] = StanceEntry.PHASE
		StanceEntry.PHASE:
			failure = StanceEntry.advance_neutral_v1(successor, event, walking_policy_id) if StanceEntry.selected_v1(walking_policy_id) else "R10H_UNSELECTED_NEUTRAL_PHASE"
		PHASE_DESCENT:
			failure = _advance_descent_v1(successor, event)
		Prior.PHASE_CONFIRM_PRONE:
			failure = Prior._advance_confirm_prone_v1(successor, event, owner_for_phase_v1(phase, controller_id))
		Prior.PHASE_POST_KICK_RECOVERY:
			# Canonical 1200-step budget begins at prone; the energy epoch does
			# not. The handoff sample belongs to both counters exactly once.
			failure = Prior._advance_post_kick_recovery_v1(successor, event,
				Prior.MAXIMUM_POST_KICK_RECOVERY_EPOCH_STEPS + int(state["passive_descent_step_count"]) - 1,
				owner_for_phase_v1(phase, controller_id))
		Prior.PHASE_WALKING_RESUME:
			failure = Prior._advance_walking_resume_v1(successor, event, WalkingPolicy.owner_for_phase_v1(phase, walking_policy_id), 1720 if WalkingPolicy.measured_body_selected_v1(walking_policy_id) else Prior.WALKING_RESUME_STEPS)
		Prior.PHASE_MATCHED_CONTINUATION:
			failure = Prior._advance_matched_continuation_v1(successor, event, WalkingPolicy.owner_for_phase_v1(phase, walking_policy_id))
		_:
			failure = "PASSIVE_ORCHESTRATOR_PHASE_UNKNOWN"
	if failure != "":
		return _failure(failure)
	if successor["total_completed_solver_step_count"] > Prior.MAXIMUM_ACTIVE_ARM_SOLVER_STEPS + int(state["maximum_passive_descent_steps"]) - 1:
		return _failure("PASSIVE_ORCHESTRATOR_TOTAL_BOUND_EXCEEDED")
	successor["payload_sha256"] = Prior._payload_sha256_v1(sdk, successor)
	if not state_valid_v1(sdk, successor, controller_id, walking_policy_id):
		return _failure("PASSIVE_ORCHESTRATOR_SUCCESSOR_INVALID")
	return {"schema_version": _schema_for_route_v1("sporespore_development_measured_prone_entry_advance_v1", controller_id, walking_policy_id), "ok": true,
		"ledger_scope": {"subsystem": "recovery", "engine_scope": "godot_jolt", "authority_mode": "development_orchestration", "question_class": "development"},
		"event_sha256": event["payload_sha256"], "state_before_sha256": state["payload_sha256"],
		"state_after": successor, "state_after_sha256": successor["payload_sha256"],
		"source_phase": phase, "next_phase": successor["phase"],
		"global_semantic_step": event["global_semantic_step"], "input_state_mutated": false,
		"world_build_count": 0, "solver_step_count": 0, "native_readback_count": 0,
		"physics_state_modified": false, "physical_acceptance_authority": false, "release_authority": false}


static func _advance_descent_v1(state: Dictionary, event: Dictionary) -> String:
	var local_step: int = event["global_semantic_step"] - state["epoch_start_global_step"]
	if (event["event_kind"] != "passive_entry_observation" or event["control_owner"] != "none"
		or event["actuation_owner"] != "none" or not event["no_actuation_requested"]
		or event["walking_actuation_applied"] or event["recovery_actuation_applied"]
		or event["walking_session_id"] != "" or event["walking_session_local_step"] != 0
		or event["recovery_epoch_local_step"] != local_step
		or event["energy_initializer_sha256"] != state["energy_initializer_sha256"]
		or event["interaction_receipt_sha256"] != "" or event["kick_application_count"] != 0
		or event["recovery_controller_terminal_phase"] != "" or event["recovery_controller_terminal_reason"] != ""
		or event["walking_motors_enabled_during_interaction_solve"]
		or event["walking_motors_disabled_in_same_pre_solver_event"]):
		return "PASSIVE_ORCHESTRATOR_DESCENT_EVENT_INVALID"
	state["passive_descent_step_count"] += 1
	state["recovery_epoch_step_count"] = local_step
	if local_step != state["passive_descent_step_count"]:
		return "PASSIVE_ORCHESTRATOR_DESCENT_SEQUENCE_INVALID"
	var status: String = event["passive_entry_status"]
	if status == "prone_handoff":
		state["canonical_start_global_step"] = event["global_semantic_step"]
		state["confirm_prone_step_count"] = 1
		state["consecutive_prone_sample_count"] = 1
		state["phase"] = Prior.PHASE_CONFIRM_PRONE
	elif status == "descent_timeout":
		if local_step != state["maximum_passive_descent_steps"]:
			return "PASSIVE_ORCHESTRATOR_PREMATURE_DESCENT_TIMEOUT"
		state["phase"] = Prior.PHASE_FAILED
		state["terminal_outcome"] = "failed"
		state["terminal_reason"] = "passive_descent_timeout"
	elif local_step >= state["maximum_passive_descent_steps"]:
		return "PASSIVE_ORCHESTRATOR_MISSING_DESCENT_TIMEOUT"
	return ""


static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "failure_code": reason, "world_build_count": 0,
		"solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}
