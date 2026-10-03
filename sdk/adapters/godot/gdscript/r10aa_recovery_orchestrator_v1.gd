extends RefCounted
# gdlint: disable=max-line-length

## R10AA retains distinct upright, partial and canonical branch histories.
## Existing r10v field names are structural slots in these new R10AA schemas;
## no retained R10V event or state is converted to successor evidence.
## A partial fall never creates canonical initialization or confirmation counts.
const Passive := preload("res://sdk/adapters/godot/gdscript/development_passive_entry_orchestrator_v1.gd")
const Prior := Passive.Prior
const Hold := Passive.StanceEntry
const Source := preload("res://sdk/adapters/godot/gdscript/r10aa_partial_task_source_v1.gd")
const Upright := preload("res://sdk/adapters/godot/gdscript/r10r_upright_task_source_v1.gd")
const Settling := preload("res://sdk/adapters/godot/gdscript/r10v_post_recovery_settling_v1.gd")
const PHASE_SETTLING := "post_recovery_stationary_settling"
const PHASE_UPRIGHT := "measured_upright_stabilization"
const UPRIGHT_FIELDS := ["upright_start_global_step", "upright_recovery_step_count", "upright_phase",
	"upright_declaration_sha256", "upright_memory_sha256", "upright_stabilization_complete"]
const STATE := "sporespore_r10aa_recovery_orchestrator_state_v1"
const EVENT := "sporespore_r10aa_recovery_orchestrator_event_v1"
const ID := "sporespore_r10aa_recovery_orchestrator_v1"
const PHASE_PARTIAL := "measured_partial_fall_recovery"
const ROUTE := "r10aa_partial_load_seeking_route_v1"
const CONTROLLER := "sporespore_exact_s169_prone_to_standing_controller_v20"
const EXTRA := ["r10v_entry_kind", "partial_start_global_step", "partial_recovery_step_count",
	"partial_phase", "partial_declaration_sha256", "partial_memory_sha256", "partial_standing_complete", "post_recovery_settling"] + UPRIGHT_FIELDS
const EVENT_EXTRA := ["r10v_native_receipt", "partial_prior_memory_sha256", "upright_prior_memory_sha256",
	"post_recovery_readiness", "post_recovery_readiness_source_sha256"]

static func initialize_v1(sdk: Object, attempt: String, arm: String, model: String,
	configuration: String, population: String) -> Dictionary:
	var result := Prior.initialize_v1(sdk, attempt, arm, model, configuration, population)
	if result.get("ok") != true: return result
	# This is a fresh zero-step template, before any event has been observed.
	var state: Dictionary = result.state
	state.schema_version = STATE
	state.orchestrator_id = ID
	state.merge({"passive_descent_step_count": 0, "maximum_passive_descent_steps": 240,
		"canonical_start_global_step": null, "r10v_entry_kind": "unselected",
		"partial_start_global_step": null, "partial_recovery_step_count": 0,
		"partial_phase": "", "partial_declaration_sha256": "", "partial_memory_sha256": "",
		"partial_standing_complete": false})
	state.merge({"upright_start_global_step": null, "upright_recovery_step_count": 0,
		"upright_phase": "", "upright_declaration_sha256": "", "upright_memory_sha256": "",
		"upright_stabilization_complete": false})
	state.merge(Hold.initial_fields_for_v1(Hold.HOLD_ID))
	state["post_recovery_settling"] = {}
	state.payload_sha256 = Prior._payload_sha256_v1(sdk, state)
	if not state_valid_v1(sdk, state): return _failure("INITIAL_STATE")
	result.schema_version = "sporespore_r10aa_recovery_orchestrator_initialization_v1"
	return result

static func state_valid_v1(sdk: Object, state: Dictionary) -> bool:
	if not Prior._state_valid_shape_v1(sdk, state,
		Prior.STATE_KEYS + Passive.STATE_EXTRA + Hold.initial_fields_for_v1(Hold.HOLD_ID).keys() + EXTRA,
		STATE, ID, [Passive.PHASE_DESCENT, Hold.PHASE, PHASE_PARTIAL, PHASE_UPRIGHT, PHASE_SETTLING],
		[Passive.PHASE_DESCENT, Hold.PHASE, PHASE_PARTIAL, PHASE_UPRIGHT, PHASE_SETTLING]): return false
	if not Hold.state_fields_valid_for_v1(state, Hold.HOLD_ID): return false
	if not _settling_state_valid(sdk, state): return false
	for key in ["passive_descent_step_count", "maximum_passive_descent_steps", "partial_recovery_step_count", "upright_recovery_step_count"]:
		if typeof(state.get(key)) != TYPE_INT: return false
	if (state.maximum_passive_descent_steps != 240 or state.passive_descent_step_count < 0
		or state.passive_descent_step_count > 240 or state.partial_recovery_step_count < 0
		or state.partial_recovery_step_count > 1200 or typeof(state.partial_standing_complete) != TYPE_BOOL
		or state.upright_recovery_step_count < 0 or state.upright_recovery_step_count > 1200
		or typeof(state.upright_stabilization_complete) != TYPE_BOOL
		or state.r10v_entry_kind not in ["unselected", "waiting", "prone", "partial", "upright", "timeout"]): return false
	var phase: String = state.phase
	var kind: String = state.r10v_entry_kind
	if kind != "upright" and (not _upright_absent(state) or phase == PHASE_UPRIGHT): return false
	if state.arm_id == Prior.EnergyInitializer.BASELINE_ARM_ID:
		return (kind == "unselected" and state.passive_descent_step_count == 0
			and state.canonical_start_global_step == null and _partial_absent(state)
			and state.confirm_prone_step_count == 0 and state.post_kick_recovery_step_count == 0
			and state.walking_resume_step_count == 0 and phase not in [PHASE_PARTIAL,
				Passive.PHASE_DESCENT, Prior.PHASE_CONFIRM_PRONE, Prior.PHASE_POST_KICK_RECOVERY, Prior.PHASE_WALKING_RESUME])
	if phase in [Prior.PHASE_PRECONDITION_RECOVERY, Prior.PHASE_WALKING_PREFIX, Prior.PHASE_INTERACTION]:
		return kind == "unselected" and state.passive_descent_step_count == 0 and state.canonical_start_global_step == null and _partial_absent(state)
	if phase == Passive.PHASE_DESCENT:
		return (kind in ["unselected", "waiting"] and state.passive_descent_step_count < 240
			and state.passive_descent_step_count == state.recovery_epoch_step_count
			and state.passive_descent_step_count == state.previous_global_semantic_step - state.epoch_start_global_step
			and state.canonical_start_global_step == null and _partial_absent(state)
			and state.confirm_prone_step_count == 0 and state.post_kick_recovery_step_count == 0 and state.walking_resume_step_count == 0)
	if kind == "upright":
		if (not _partial_absent(state) or typeof(state.upright_start_global_step) != TYPE_INT or state.passive_descent_step_count != 240
			or state.upright_start_global_step != state.epoch_start_global_step + 240
			or state.canonical_start_global_step != null or state.confirm_prone_step_count != 0
			or state.consecutive_prone_sample_count != 0 or state.post_kick_recovery_step_count != 0
			or not Source._digest(state.upright_declaration_sha256) or not Source._digest(state.upright_memory_sha256)
			or state.upright_phase not in Upright.PHASES + ["complete", "failed"]
			or state.upright_stabilization_complete != (state.upright_phase == "complete")
			or state.previous_global_semantic_step != state.upright_start_global_step + state.upright_recovery_step_count + _settling_commands(state) + state.walking_resume_step_count): return false
		if phase == PHASE_UPRIGHT:
			return state.upright_phase in Upright.PHASES and state.upright_recovery_step_count < 1200 and state.walking_resume_step_count == 0
		if phase in [Prior.PHASE_WALKING_RESUME, Prior.PHASE_COMPLETE]: return state.upright_stabilization_complete
		if phase == PHASE_SETTLING: return state.upright_stabilization_complete and state.walking_resume_step_count == 0
		if phase == Prior.PHASE_FAILED and state.upright_stabilization_complete:
			return state.post_recovery_settling.get("outcome") in ["timeout", "entry_refused"]
		return phase == Prior.PHASE_FAILED and state.upright_phase == "failed"
	if kind == "partial":
		if (typeof(state.partial_start_global_step) != TYPE_INT or state.passive_descent_step_count != 240
			or state.partial_start_global_step != state.epoch_start_global_step + 240
			or state.canonical_start_global_step != null or state.confirm_prone_step_count != 0
			or state.consecutive_prone_sample_count != 0 or state.post_kick_recovery_step_count != 0
			or not Source._digest(state.partial_declaration_sha256) or not Source._digest(state.partial_memory_sha256)
			or state.partial_phase not in Source.PHASES + ["complete", "failed"]
			or state.partial_standing_complete != (state.partial_phase == "complete")
			or state.previous_global_semantic_step != state.partial_start_global_step + state.partial_recovery_step_count + state.walking_resume_step_count): return false
		if phase == PHASE_PARTIAL:
			return state.partial_phase in Source.PHASES and state.partial_recovery_step_count < 1200 and state.walking_resume_step_count == 0
		if phase in [Prior.PHASE_WALKING_RESUME, Prior.PHASE_COMPLETE]: return state.partial_standing_complete
		return phase == Prior.PHASE_FAILED and state.partial_phase == "failed"
	if not _partial_absent(state) or phase == PHASE_PARTIAL: return false
	if kind == "prone":
		return (typeof(state.canonical_start_global_step) == TYPE_INT and state.passive_descent_step_count >= 1
			and state.canonical_start_global_step == state.epoch_start_global_step + state.passive_descent_step_count
			and state.canonical_start_global_step <= state.previous_global_semantic_step and state.confirm_prone_step_count >= 1
			and phase in [Prior.PHASE_CONFIRM_PRONE, Prior.PHASE_POST_KICK_RECOVERY, Prior.PHASE_WALKING_RESUME, Prior.PHASE_COMPLETE, Prior.PHASE_FAILED])
	return (phase == Prior.PHASE_FAILED and state.canonical_start_global_step == null
		and state.confirm_prone_step_count == 0 and state.post_kick_recovery_step_count == 0 and state.walking_resume_step_count == 0
		and (kind == "timeout" and state.passive_descent_step_count == 240 or kind == "unselected" and state.epoch_start_global_step == null))

static func _partial_absent(state: Dictionary) -> bool:
	return (state.partial_start_global_step == null and state.partial_recovery_step_count == 0
		and state.partial_phase == "" and state.partial_declaration_sha256 == ""
		and state.partial_memory_sha256 == "" and not state.partial_standing_complete)

static func _upright_absent(state: Dictionary) -> bool:
	return (state.upright_start_global_step == null and state.upright_recovery_step_count == 0
		and state.upright_phase == "" and state.upright_declaration_sha256 == ""
		and state.upright_memory_sha256 == "" and not state.upright_stabilization_complete)

static func recovery_owner_v1(phase: String) -> String:
	return "recovery_v6" if phase == Prior.PHASE_PRECONDITION_RECOVERY else "recovery_candidate"

static func walking_owner_v1(phase: String) -> String:
	return "stance" if phase in [Hold.PHASE, PHASE_SETTLING, Prior.PHASE_WALKING_RESUME, Prior.PHASE_MATCHED_CONTINUATION] else "walking_bw5r_b"

static func build_event_v1(sdk: Object, state: Dictionary, fields: Dictionary) -> Dictionary:
	if not state_valid_v1(sdk, state): return _failure("EVENT_STATE")
	var extras := {"passive_entry_receipt_sha256": fields.get("passive_entry_receipt_sha256", ""),
		"passive_entry_status": fields.get("passive_entry_status", ""),
		"canonical_initialization_count": fields.get("canonical_initialization_count", 0),
		"neutral_entry_readiness_sha256": fields.get("neutral_entry_readiness_sha256", ""),
		"neutral_entry_ready": fields.get("neutral_entry_ready", false),
		"r10v_native_receipt": fields.get("r10v_native_receipt", {}),
		"partial_prior_memory_sha256": fields.get("partial_prior_memory_sha256", ""),
		"upright_prior_memory_sha256": fields.get("upright_prior_memory_sha256", ""),
		"post_recovery_readiness": fields.get("post_recovery_readiness", {}),
		"post_recovery_readiness_source_sha256": fields.get("post_recovery_readiness_source_sha256", "")}
	var result := Prior._build_event_for_shape_v1(sdk, state, fields, EVENT, ID,
		_event_keys(), extras, recovery_owner_v1(state.phase), walking_owner_v1(state.phase))
	if result.get("ok") != true or not event_valid_v1(sdk, result.event): return _failure("EVENT_FIELDS")
	result.schema_version = "sporespore_r10aa_recovery_orchestrator_event_build_v1"
	return result

static func _event_keys() -> Array:
	return Prior.EVENT_KEYS + Passive.EVENT_EXTRA + ["neutral_entry_readiness_sha256", "neutral_entry_ready"] + EVENT_EXTRA

static func event_valid_v1(sdk: Object, event: Dictionary) -> bool:
	var phase: String = event.get("source_phase", "")
	if not Prior._event_valid_shape_v1(sdk, event, _event_keys(), EVENT, ID,
		recovery_owner_v1(phase), walking_owner_v1(phase)): return false
	if typeof(event.neutral_entry_ready) != TYPE_BOOL or not (event.r10v_native_receipt is Dictionary): return false
	if not _settling_event_valid(event): return false
	if phase == Hold.PHASE:
		if not Source._digest(event.neutral_entry_readiness_sha256): return false
	elif event.neutral_entry_readiness_sha256 != "" or event.neutral_entry_ready: return false
	if phase != PHASE_UPRIGHT and event.upright_prior_memory_sha256 != "": return false
	if phase not in [Passive.PHASE_DESCENT, PHASE_PARTIAL, PHASE_UPRIGHT]:
		return (event.r10v_native_receipt.is_empty() and event.partial_prior_memory_sha256 == ""
			and event.passive_entry_receipt_sha256 == "" and event.passive_entry_status == "" and event.canonical_initialization_count == 0)
	var native: Dictionary = event.r10v_native_receipt
	if not _native_flags_valid(native): return false
	if phase == PHASE_UPRIGHT: return _upright_event_valid(sdk, event, native)
	if phase == Passive.PHASE_DESCENT:
		var successor: Dictionary = native
		if (successor.get("schema_version") != "sporespore_r10aa_partial_load_seeking_entry_control_receipt_v1"
			or successor.get("control_composition_id") != Source.COMPOSITION
			or not (successor.get("original_entry_control") is Dictionary)): return false
		native = successor.original_entry_control
		if not _native_flags_valid(native): return false
		if (native.get("schema_version") != "sporespore_r10q_upright_entry_control_receipt_v1"
			or not (native.get("entry") is Dictionary) or not (native.get("original_control") is Dictionary)
			or native.entry.get("original_entry") != native.original_control.get("entry")
			or native.get("partial_supervisor_synthesized") != false): return false
		var wrapper: Dictionary = native
		var selected: Variant = wrapper.entry.get("memory", {}).get("route")
		native = wrapper.original_control
		if not _native_flags_valid(native): return false
		if native.get("schema_version") != "sporespore_r10k_entry_control_receipt_v1" or not (native.get("entry") is Dictionary): return false
		var entry: Dictionary = native.entry
		if not (entry.get("original_passive_receipt") is Dictionary) or not (entry.get("memory") is Dictionary): return false
		var original: Dictionary = entry.original_passive_receipt
		var kind: Variant = entry.memory.get("route")
		if selected == "upright":
			if (kind != "timeout" or not (wrapper.entry.get("upright_memory") is Dictionary)
				or not (wrapper.entry.get("upright_declaration") is Dictionary)
				or wrapper.entry.memory.get("consecutive_upright_samples") != 12
				or wrapper.entry.memory.get("original_memory") != entry.memory
				or Upright.control_context_v1(sdk, wrapper).get("ok") != true): return false
		elif selected != kind or wrapper.entry.get("upright_memory") != null or wrapper.entry.get("upright_declaration") != null or wrapper.get("initial_upright_control") != null:
			return false
		return (kind in ["waiting", "prone", "partial", "timeout"] and event.partial_prior_memory_sha256 == ""
			and event.passive_entry_receipt_sha256 == Source._sha(sdk, original)
			and event.passive_entry_status == original.get("memory", {}).get("status")
			and event.canonical_initialization_count == original.get("canonical_initialization_count")
			and event.canonical_initialization_count == (1 if kind == "prone" else 0)
			and event.prone_sample == (kind == "prone")
			and original.get("memory", {}).get("last_semantic_step") == event.global_semantic_step
			and entry.memory.get("passive_memory") == original.get("memory")
			and (Source.control_context_v1(sdk, successor).get("ok") == true if kind == "partial" else
				successor.get("initial_partial_control") == null and successor.get("initial_load_plan") == null))
	if (native.get("schema_version") != "sporespore_r10aa_partial_load_seeking_step_control_receipt_v1"
		or native.get("control_composition_id") != Source.COMPOSITION
		or not (native.get("step") is Dictionary) or not Source._digest(event.partial_prior_memory_sha256)
		or event.passive_entry_receipt_sha256 != "" or event.passive_entry_status != "" or event.canonical_initialization_count != 0): return false
	var step: Dictionary = native.step
	if (step.get("schema_version") != "sporespore_partial_fall_step_receipt_v1" or step.get("task_id") != Source.TASK
		or step.get("semantics_id") != Source.SEMANTICS or not (step.get("memory") is Dictionary)
		or step.get("energy_epoch_reset") != false or step.get("prone_to_standing_claimed") != false
		or step.get("physical_acceptance_authority") != false or step.get("release_authority") != false): return false
	var memory: Dictionary = step.memory
	var terminal: Variant = step.get("next_phase")
	if (memory.get("last_semantic_step") != event.global_semantic_step or memory.get("phase") != terminal
		or memory.get("last_observation_sha256") != step.get("observation_sha256")
		or step.get("prior_phase") not in Source.PHASES or terminal not in Source.PHASES + ["complete", "failed"]
		or step.get("partial_fall_standing_complete") != (terminal == "complete")
		or event.stable_four_foot_stance != step.get("classification", {}).get("stable_stance_gate")): return false
	if terminal in ["complete", "failed"]:
		return (native.get("next_control") == null and native.get("next_load_plan") == null
			and event.recovery_controller_terminal_phase == terminal
			and event.recovery_controller_terminal_reason == (memory.get("terminal_failure_code") if terminal == "failed" else "")
			and (terminal != "complete" or memory.get("standing_samples_observed") == 60 and event.stable_four_foot_stance))
	return (Source.control_context_v1(sdk, native).get("ok") == true
		and event.recovery_controller_terminal_phase == "" and event.recovery_controller_terminal_reason == "")

static func _upright_event_valid(sdk: Object, event: Dictionary, native: Dictionary) -> bool:
	if (native.get("schema_version") != "sporespore_r10r_upright_direct_rise_step_control_receipt_v1"
		or native.get("control_composition_id") != Upright.COMPOSITION
		or not (native.get("step") is Dictionary) or not Source._digest(event.upright_prior_memory_sha256)
		or event.passive_entry_receipt_sha256 != "" or event.passive_entry_status != "" or event.canonical_initialization_count != 0): return false
	var step: Dictionary = native.step
	if (step.get("schema_version") != "sporespore_upright_recovery_step_receipt_v1" or step.get("task_id") != Upright.TASK
		or step.get("semantics_id") != Upright.SEMANTICS or not (step.get("memory") is Dictionary)
		or event.partial_prior_memory_sha256 != "" or step.get("partial_fall_standing_claimed") != false
		or step.get("energy_epoch_reset") != false or step.get("prone_to_standing_claimed") != false
		or step.get("physical_acceptance_authority") != false or step.get("release_authority") != false): return false
	var memory: Dictionary = step.memory
	var terminal: Variant = step.get("next_phase")
	if (memory.get("last_semantic_step") != event.global_semantic_step or memory.get("phase") != terminal
		or memory.get("last_observation_sha256") != step.get("observation_sha256")
		or step.get("prior_phase") not in Upright.PHASES or terminal not in Upright.PHASES + ["complete", "failed"]
		or step.get("upright_stabilization_complete") != (terminal == "complete")
		or event.stable_four_foot_stance != step.get("classification", {}).get("stable_stance_gate")): return false
	if terminal in ["complete", "failed"]:
		return (native.get("next_control") == null and event.recovery_controller_terminal_phase == terminal
			and event.recovery_controller_terminal_reason == (memory.get("terminal_failure_code") if terminal == "failed" else "")
			and (terminal != "complete" or memory.get("standing_samples_observed") == 60 and event.stable_four_foot_stance))
	return (Upright.control_context_v1(sdk, native).get("ok") == true
		and event.recovery_controller_terminal_phase == "" and event.recovery_controller_terminal_reason == "")

static func _native_flags_valid(native: Dictionary) -> bool:
	for flag in ["original_observation_rewritten", "canonical_supervisor_synthesized", "physical_acceptance_authority", "release_authority"]:
		if native.get(flag) != false: return false
	return native.get("world_build_count") == 0 and native.get("solver_step_count") == 0

static func advance_v1(sdk: Object, state: Dictionary, event: Dictionary) -> Dictionary:
	if not state_valid_v1(sdk, state) or not event_valid_v1(sdk, event): return _failure("STATE_OR_EVENT")
	var phase: String = state.phase
	if phase in [Prior.PHASE_COMPLETE, Prior.PHASE_FAILED]: return _failure("ALREADY_TERMINAL")
	for key in ["orchestrator_id", "attempt_id", "arm_id", "model_instance_id", "frozen_configuration_sha256", "body_population_instance_sha256", "ordered_same_body_node_ids"]:
		if state[key] != event[key]: return _failure("IDENTITY:" + key)
	if event.source_phase != phase or event.global_semantic_step != state.previous_global_semantic_step + 1: return _failure("SEQUENCE")
	for key in ["body_population_rebuild_count", "body_transform_write_count", "body_velocity_write_count", "solver_reset_count"]:
		if event[key] != 0: return _failure("FORBIDDEN_MUTATION:" + key)
	var successor := state.duplicate(true)
	successor.previous_global_semantic_step = event.global_semantic_step
	successor.total_completed_solver_step_count += 1
	successor.state_revision += 1
	var failure := ""
	match phase:
		Prior.PHASE_PRECONDITION_RECOVERY: failure = Prior._advance_precondition_v1(successor, event)
		Prior.PHASE_WALKING_PREFIX: failure = Prior._advance_walking_prefix_v1(successor, event, 30)
		Prior.PHASE_INTERACTION:
			failure = Prior._advance_interaction_v1(successor, event)
			if failure == "": successor.phase = Passive.PHASE_DESCENT if state.arm_id == Prior.EnergyInitializer.ACTIVE_ARM_ID else Hold.PHASE
		Hold.PHASE: failure = Hold.advance_hold_route_v1(successor, event, Hold.HOLD_ID)
		Passive.PHASE_DESCENT: failure = _advance_descent(sdk, successor, event)
		PHASE_PARTIAL: failure = _advance_partial(sdk, successor, event)
		PHASE_UPRIGHT: failure = _advance_upright(sdk, successor, event)
		PHASE_SETTLING: failure = _advance_settling(sdk, successor, event)
		Prior.PHASE_CONFIRM_PRONE: failure = Prior._advance_confirm_prone_v1(successor, event, recovery_owner_v1(phase))
		Prior.PHASE_POST_KICK_RECOVERY:
			failure = Prior._advance_post_kick_recovery_v1(successor, event, 1200 + state.passive_descent_step_count - 1, recovery_owner_v1(phase))
		Prior.PHASE_WALKING_RESUME:
			if not state.post_recovery_settling.is_empty() and event.walking_session_id == state.post_recovery_settling.hold_session_id:
				failure = "WALKING_REUSES_SETTLING_SESSION"
			else: failure = Prior._advance_walking_resume_v1(successor, event, "stance", 1720)
		Prior.PHASE_MATCHED_CONTINUATION: failure = Prior._advance_matched_continuation_v1(successor, event, "stance")
		_: failure = "UNKNOWN_PHASE"
	if failure != "": return _failure(failure)
	# Unchanged R10V maximum; no-kick retains its smaller role ceiling.
	if successor.total_completed_solver_step_count > (3752 if successor.arm_id == Prior.EnergyInitializer.ACTIVE_ARM_ID else 2552): return _failure("TOTAL_BOUND")
	successor.payload_sha256 = Prior._payload_sha256_v1(sdk, successor)
	if not state_valid_v1(sdk, successor): return _failure("SUCCESSOR_STATE")
	return {"schema_version": "sporespore_r10aa_recovery_orchestrator_advance_v1", "ok": true,
		"ledger_scope": {"subsystem": "recovery", "engine_scope": "godot_jolt", "authority_mode": "development_orchestration", "question_class": "development"},
		"event_sha256": event.payload_sha256, "state_before_sha256": state.payload_sha256,
		"state_after": successor, "state_after_sha256": successor.payload_sha256,
		"source_phase": phase, "next_phase": successor.phase, "global_semantic_step": event.global_semantic_step,
		"input_state_mutated": false, "world_build_count": 0, "solver_step_count": 0,
		"native_readback_count": 0, "physics_state_modified": false,
		"physical_acceptance_authority": false, "release_authority": false}

static func _advance_descent(sdk: Object, state: Dictionary, event: Dictionary) -> String:
	var local_step: int = event.global_semantic_step - state.epoch_start_global_step
	if (event.event_kind != "passive_entry_observation" or event.control_owner != "none" or event.actuation_owner != "none"
		or not event.no_actuation_requested or event.walking_actuation_applied or event.recovery_actuation_applied
		or event.walking_session_id != "" or event.walking_session_local_step != 0
		or event.recovery_epoch_local_step != local_step or event.energy_initializer_sha256 != state.energy_initializer_sha256
		or event.interaction_receipt_sha256 != "" or event.kick_application_count != 0
		or event.recovery_controller_terminal_phase != "" or event.recovery_controller_terminal_reason != ""
		or event.walking_motors_enabled_during_interaction_solve or event.walking_motors_disabled_in_same_pre_solver_event): return "DESCENT_EVENT"
	state.passive_descent_step_count += 1
	state.recovery_epoch_step_count = local_step
	var wrapper: Dictionary = event.r10v_native_receipt.original_entry_control
	var entry: Dictionary = wrapper.original_control.entry
	if local_step != state.passive_descent_step_count or entry.memory.passive_memory.observations_seen != local_step: return "DESCENT_COUNT"
	state.r10v_entry_kind = wrapper.entry.memory.route
	match state.r10v_entry_kind:
		"prone":
			if event.passive_entry_status != "prone_handoff": return "PRONE_HANDOFF"
			state.canonical_start_global_step = event.global_semantic_step
			state.confirm_prone_step_count = 1
			state.consecutive_prone_sample_count = 1
			state.phase = Prior.PHASE_CONFIRM_PRONE
		"partial":
			if (local_step != 240 or event.passive_entry_status != "descent_timeout"
				or entry.original_passive_receipt.get("canonical_memory") != null
				or not (entry.get("partial_memory") is Dictionary) or not (entry.get("partial_declaration") is Dictionary)): return "PARTIAL_HANDOFF"
			var memory: Dictionary = entry.partial_memory
			if memory.get("phase") != "establish_distal_support" or memory.get("total_steps_observed") != 0 or memory.get("ordered_completed_phases") != []: return "PARTIAL_INITIAL_HISTORY"
			state.partial_start_global_step = event.global_semantic_step
			state.partial_phase = memory.phase
			state.partial_declaration_sha256 = Source._sha(sdk, entry.partial_declaration)
			if memory.declaration_sha256 != state.partial_declaration_sha256: return "PARTIAL_DECLARATION"
			state.partial_memory_sha256 = Source._sha(sdk, memory)
			state.phase = PHASE_PARTIAL
		"upright":
			if (local_step != 240 or entry.memory.route != "timeout" or event.passive_entry_status != "descent_timeout"
				or entry.original_passive_receipt.get("canonical_memory") != null
				or entry.get("partial_memory") != null): return "UPRIGHT_HANDOFF"
			var memory: Dictionary = wrapper.entry.upright_memory
			if memory.get("phase") != "establish_distal_support" or memory.get("total_steps_observed") != 0 or memory.get("ordered_completed_phases") != []: return "UPRIGHT_INITIAL_HISTORY"
			state.upright_start_global_step = event.global_semantic_step
			state.upright_phase = memory.phase
			state.upright_declaration_sha256 = Source._sha(sdk, wrapper.entry.upright_declaration)
			if memory.declaration_sha256 != state.upright_declaration_sha256: return "UPRIGHT_DECLARATION"
			state.upright_memory_sha256 = Source._sha(sdk, memory)
			state.phase = PHASE_UPRIGHT
		"timeout":
			if local_step != 240 or event.passive_entry_status != "descent_timeout": return "PREMATURE_TIMEOUT"
			state.phase = Prior.PHASE_FAILED
			state.terminal_outcome = "failed"
			state.terminal_reason = "passive_descent_timeout_no_qualified_entry"
		"waiting":
			if local_step >= 240 or event.passive_entry_status != "waiting_for_prone": return "WAIT_BOUND"
		_: return "ENTRY_KIND"
	return ""

static func _advance_partial(sdk: Object, state: Dictionary, event: Dictionary) -> String:
	var step: Dictionary = event.r10v_native_receipt.step
	var memory: Dictionary = step.memory
	var count: int = state.partial_recovery_step_count + 1
	if (event.event_kind != "partial_fall_controller_step" or event.control_owner != "recovery_candidate"
		or event.actuation_owner != "recovery_candidate" or event.no_actuation_requested
		or not event.recovery_actuation_applied or event.walking_actuation_applied
		or event.walking_session_id != "" or event.walking_session_local_step != 0
		or event.energy_initializer_sha256 != state.energy_initializer_sha256 or event.interaction_receipt_sha256 != ""
		or event.kick_application_count != 0 or event.prone_sample
		or event.walking_motors_enabled_during_interaction_solve or event.walking_motors_disabled_in_same_pre_solver_event
		or event.recovery_epoch_local_step != event.global_semantic_step - state.epoch_start_global_step
		or event.partial_prior_memory_sha256 != state.partial_memory_sha256
		or step.prior_phase != state.partial_phase or memory.declaration_sha256 != state.partial_declaration_sha256
		or memory.total_steps_observed != count or count > 1200): return "PARTIAL_EVENT"
	state.partial_recovery_step_count = count
	state.recovery_epoch_step_count = event.recovery_epoch_local_step
	state.partial_phase = memory.phase
	state.partial_memory_sha256 = Source._sha(sdk, memory)
	state.partial_standing_complete = step.partial_fall_standing_complete
	if memory.phase == "complete": state.phase = Prior.PHASE_WALKING_RESUME
	elif memory.phase == "failed":
		state.phase = Prior.PHASE_FAILED
		state.terminal_outcome = "failed"
		state.terminal_reason = memory.terminal_failure_code
	elif count == 1200: return "MISSING_NATIVE_TOTAL_TIMEOUT"
	return ""

static func _advance_upright(sdk: Object, state: Dictionary, event: Dictionary) -> String:
	var step: Dictionary = event.r10v_native_receipt.step
	var memory: Dictionary = step.memory
	var count: int = state.upright_recovery_step_count + 1
	if (event.event_kind != "upright_recovery_controller_step" or event.control_owner != "recovery_candidate"
		or event.actuation_owner != "recovery_candidate" or event.no_actuation_requested
		or not event.recovery_actuation_applied or event.walking_actuation_applied
		or event.walking_session_id != "" or event.walking_session_local_step != 0
		or event.energy_initializer_sha256 != state.energy_initializer_sha256 or event.interaction_receipt_sha256 != ""
		or event.kick_application_count != 0 or event.prone_sample
		or event.walking_motors_enabled_during_interaction_solve or event.walking_motors_disabled_in_same_pre_solver_event
		or event.recovery_epoch_local_step != event.global_semantic_step - state.epoch_start_global_step
		or event.upright_prior_memory_sha256 != state.upright_memory_sha256
		or step.prior_phase != state.upright_phase or memory.declaration_sha256 != state.upright_declaration_sha256
		or memory.total_steps_observed != count or count > 1200): return "UPRIGHT_EVENT"
	state.upright_recovery_step_count = count
	state.recovery_epoch_step_count = event.recovery_epoch_local_step
	state.upright_phase = memory.phase
	state.upright_memory_sha256 = Source._sha(sdk, memory)
	state.upright_stabilization_complete = step.upright_stabilization_complete
	if memory.phase == "complete": return _initialize_settling(sdk, state, event)
	elif memory.phase == "failed":
		state.phase = Prior.PHASE_FAILED
		state.terminal_outcome = "failed"
		state.terminal_reason = memory.terminal_failure_code
	elif count == 1200: return "MISSING_NATIVE_TOTAL_TIMEOUT"
	return ""

static func _settling_commands(state: Dictionary) -> int:
	return int(state.get("post_recovery_settling", {}).get("commands", 0))

static func _settling_state_valid(sdk: Object, state: Dictionary) -> bool:
	var value: Variant = state.get("post_recovery_settling")
	if not (value is Dictionary): return false
	var memory: Dictionary = value
	if state.get("r10v_entry_kind") != "upright" or state.get("upright_phase") != "complete":
		return memory.is_empty() and state.phase != PHASE_SETTLING
	if not Settling.memory_valid_v1(sdk, memory): return false
	var context: Dictionary = memory.context
	for key in ["attempt_id", "arm_id", "model_instance_id", "body_population_instance_sha256", "energy_initializer_sha256"]:
		if context[key] != state[key]: return false
	if (context.entry_kind != "upright" or context.recovery_memory_sha256 != state.upright_memory_sha256
		or context.global_semantic_step != state.upright_start_global_step + state.upright_recovery_step_count
		or context.prior_walking_session_ids != [state.prefix_walking_session_id]): return false
	match memory.outcome:
		"pending": return state.phase == PHASE_SETTLING and state.walking_resume_step_count == 0
		"direct", "ready": return state.phase in [Prior.PHASE_WALKING_RESUME, Prior.PHASE_COMPLETE]
		"timeout": return state.phase == Prior.PHASE_FAILED and state.terminal_reason == "post_recovery_hold_timeout"
		"entry_refused": return state.phase == Prior.PHASE_FAILED and state.terminal_reason == "post_recovery_hold_entry_not_admissible"
	return false

static func _settling_event_valid(event: Dictionary) -> bool:
	if not (event.get("post_recovery_readiness") is Dictionary): return false
	var selected: bool = (event.source_phase == PHASE_SETTLING
		or event.source_phase == PHASE_UPRIGHT and event.recovery_controller_terminal_phase == "complete")
	if not selected:
		return event.post_recovery_readiness.is_empty() and event.post_recovery_readiness_source_sha256 == ""
	return (Settling.readiness_valid_v1(event.post_recovery_readiness)
		and event.post_recovery_readiness.source_semantic_step == event.global_semantic_step
		and Source._digest(event.post_recovery_readiness_source_sha256))

static func _initialize_settling(sdk: Object, state: Dictionary, event: Dictionary) -> String:
	if not state.post_recovery_settling.is_empty(): return "REPEATED_SETTLING_INITIALIZATION"
	var context := {"schema_version": Settling.CONTEXT, "entry_kind": "upright", "recovery_phase": "complete",
		"global_semantic_step": event.global_semantic_step, "recovery_memory_sha256": state.upright_memory_sha256,
		"recovery_receipt_sha256": Source._sha(sdk, event.r10v_native_receipt),
		"prior_walking_session_ids": [state.prefix_walking_session_id]}
	for key in ["attempt_id", "arm_id", "model_instance_id", "body_population_instance_sha256", "energy_initializer_sha256"]:
		context[key] = state[key]
	var initialized := Settling.initialize_v1(sdk, context, event.post_recovery_readiness)
	if initialized.get("ok") != true: return "SETTLING_INITIALIZATION"
	state.post_recovery_settling = initialized.memory
	match initialized.memory.outcome:
		"pending": state.phase = PHASE_SETTLING
		"direct": state.phase = Prior.PHASE_WALKING_RESUME
		"entry_refused":
			state.phase = Prior.PHASE_FAILED
			state.terminal_outcome = "failed"
			state.terminal_reason = "post_recovery_hold_entry_not_admissible"
		_: return "SETTLING_INITIAL_OUTCOME"
	return ""

static func _advance_settling(sdk: Object, state: Dictionary, event: Dictionary) -> String:
	var memory: Dictionary = state.post_recovery_settling
	if (event.event_kind != "post_recovery_hold_step" or event.control_owner != "stance" or event.actuation_owner != "stance"
		or event.no_actuation_requested or not event.walking_actuation_applied or event.recovery_actuation_applied
		or event.walking_session_local_step != memory.commands + 1 or not state.resume_or_continuation_session_id.is_empty()
		or event.recovery_epoch_local_step != event.global_semantic_step - state.epoch_start_global_step
		or event.energy_initializer_sha256 != state.energy_initializer_sha256 or event.kick_application_count != 0
		or event.interaction_receipt_sha256 != "" or event.recovery_controller_terminal_phase != "" or event.recovery_controller_terminal_reason != ""
		or event.prone_sample or event.walking_motors_enabled_during_interaction_solve or event.walking_motors_disabled_in_same_pre_solver_event): return "SETTLING_EVENT"
	var advanced := Settling.advance_v1(sdk, memory, event.post_recovery_readiness, event.walking_session_id,
		state.upright_memory_sha256, event.energy_initializer_sha256)
	if advanced.get("ok") != true: return "SETTLING_STEP"
	state.post_recovery_settling = advanced.memory
	state.recovery_epoch_step_count = event.recovery_epoch_local_step
	if advanced.memory.outcome == "ready": state.phase = Prior.PHASE_WALKING_RESUME
	elif advanced.memory.outcome == "timeout":
		state.phase = Prior.PHASE_FAILED
		state.terminal_outcome = "failed"
		state.terminal_reason = "post_recovery_hold_timeout"
	return ""

static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": "R10AA_ORCHESTRATOR_" + code,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}
