extends "res://sdk/adapters/godot/gdscript/development_recovery_candidate_worker_v1.gd"
# gdlint: disable=max-line-length

## R10S production hooks. Prospective profile/launcher integration must bind
## this worker separately; the native component profile cannot launch a route.
const R10SSeed := preload("res://sdk/adapters/godot/gdscript/r10s_development_seed_v1.gd")
const R10S := preload("res://sdk/adapters/godot/gdscript/r10s_recovery_orchestrator_v1.gd")
const UprightBridge := preload("res://sdk/adapters/godot/gdscript/r10r_upright_recovery_stage_v1.gd")
var _r10s_upright_packets: Array = []
var _r10s_first_upright_application: Dictionary = {}

func _r10k_selected_v1() -> bool:
	# Reuse original partial/prone worker hooks only under this own route.
	return _candidate_selection.get("diagnostic_schedule", {}).get("walking_policy_id") == R10S.ROUTE

func _initialize_orchestrator_v1(arm_id: String, model_id: String, population: String) -> Dictionary:
	return R10S.initialize_v1(_sdk, _attempt_id, arm_id, model_id, _configuration_sha256, population)

func _build_orchestrator_event_v1(state: Dictionary, fields: Dictionary) -> Dictionary:
	# These are fresh event inputs from shared hooks, not retained old events.
	var own := fields.duplicate(true)
	if own.has("r10k_native_receipt"):
		if own.has("r10s_native_receipt"): return {"ok": false, "failure_code": "R10S_COMPETING_NATIVE_EVENT"}
		own["r10s_native_receipt"] = own.r10k_native_receipt
		own.erase("r10k_native_receipt")
	return R10S.build_event_v1(_sdk, state, own)

func _advance_orchestrator_step_v1(state: Dictionary, event: Dictionary) -> Dictionary:
	var result := R10S.advance_v1(_sdk, state, event)
	_entry_transitions.append({"state_before": state.duplicate(true), "event": event.duplicate(true), "advance": result.duplicate(true)})
	if result.get("ok") == true and state.phase == Orchestrator.PHASE_INTERACTION and result.next_phase == EntryOrchestrator.PHASE_DESCENT:
		# Setup remains retained in its genuine terminal source. Neither post-kick
		# branch owns canonical memory while passive descent is still running.
		var arm: Dictionary = _arms[state.arm_id]
		arm.recovery_memory = {}
		arm.next_recovery_control = {}
		arm.last_recovery_terminal = false
		arm["passive_entry_state"] = {}
		arm["passive_entry_handoff_receipt"] = {}
		arm["r10k_partial_declaration"] = {}
		arm["r10k_partial_memory"] = {}
		arm["r10k_native_receipt"] = {}
		arm["r10s_upright_declaration"] = {}
		arm["r10s_upright_memory"] = {}
		arm["r10s_native_receipt"] = {}
		_arms[state.arm_id] = arm
	return result

func _process_descent_v1(arm_id: String, global_step: int) -> Dictionary:
	var arm: Dictionary = _arms[arm_id]
	var state: Dictionary = arm.orchestrator_state
	var collection: Dictionary = arm.last_collection
	var bound: Dictionary = collection.get("epoch_result", {}).get("bound_epoch_observations", {})
	var packet := UprightBridge.entry_v1(_sdk, _context, _attempt_id, bound, arm.get("passive_entry_state", {}))
	packet["source_application"] = arm.pending_application.duplicate(true)
	_entry_packets.append(packet)
	if packet.get("ok") != true: return packet
	var original: Dictionary = packet.original_passive_receipt
	arm.passive_entry_state = packet.entry_state
	arm.last_recovery_classification = original.classification.duplicate(true)
	arm.trace_rows[-1]["recovery_classification"] = original.classification.duplicate(true)
	var kind: String = packet.entry_kind
	if kind in ["prone", "partial", "upright"]:
		if (not arm.recovery_memory.is_empty() or not arm.passive_entry_handoff_receipt.is_empty()
			or not arm.get("r10k_partial_memory", {}).is_empty() or not arm.get("r10s_upright_memory", {}).is_empty()):
			return {"ok": false, "failure_code": "R10S_RECOVERY_REINITIALIZATION"}
		if kind == "prone":
			if not (original.get("canonical_memory") is Dictionary): return {"ok": false, "failure_code": "R10S_PRONE_MEMORY_MISSING"}
			arm.recovery_memory = original.canonical_memory.duplicate(true)
			arm.passive_entry_handoff_receipt = original.duplicate(true)
			arm["first_post_entry_application_pending"] = true
		elif kind == "partial":
			var entry: Dictionary = packet.original_control_receipt.entry
			arm.r10k_partial_declaration = entry.partial_declaration.duplicate(true)
			arm.r10k_partial_memory = entry.partial_memory.duplicate(true)
			arm.r10k_native_receipt = packet.original_control_receipt.duplicate(true)
			arm.next_recovery_control = packet.original_control_receipt.initial_partial_control.duplicate(true)
		else:
			arm.r10s_upright_declaration = packet.native_receipt.entry.upright_declaration.duplicate(true)
			arm.r10s_upright_memory = packet.native_receipt.entry.upright_memory.duplicate(true)
			arm.r10s_native_receipt = packet.native_receipt.duplicate(true)
			arm.next_recovery_control = packet.native_receipt.initial_upright_control.duplicate(true)
	_arms[arm_id] = arm
	var event := _build_orchestrator_event_v1(state, {
		"event_kind": "passive_entry_observation", "global_semantic_step": global_step,
		"recovery_epoch_local_step": global_step - state.epoch_start_global_step,
		"control_owner": "none", "actuation_owner": "none", "no_actuation_requested": true,
		"application_intent_sha256": _canonical_sha256_v1(arm.pending_application),
		"energy_initializer_sha256": _arm_epoch_initializer_sha256_v1(arm),
		"prone_sample": original.classification.entry_prone_gate, "stable_four_foot_stance": original.classification.stable_stance_gate,
		"passive_entry_receipt_sha256": _canonical_sha256_v1(original), "passive_entry_status": original.memory.status,
		"canonical_initialization_count": original.canonical_initialization_count, "r10s_native_receipt": packet.native_receipt,
		"body_population_rebuild_count": arm.body_population_rebuild_count, "body_transform_write_count": arm.body_transform_write_count,
		"body_velocity_write_count": arm.body_velocity_write_count, "solver_reset_count": arm.solver_reset_count})
	return _install_orchestrator_event_v1(arm_id, state, arm.pending_application, collection, bound, event)

func _apply_recovery_control_v1(arm_id: String, completed_global_step: int) -> Dictionary:
	var upright: bool = _r10k_selected_v1() and _arms[arm_id].orchestrator_state.phase == R10S.PHASE_UPRIGHT
	if not upright: return super._apply_recovery_control_v1(arm_id, completed_global_step)
	var arm: Dictionary = _arms[arm_id]
	var context := UprightBridge.Source.control_context_v1(_sdk, arm.get("r10s_native_receipt", {}))
	if (context.get("ok") != true or context.get("memory_sha256") != _canonical_sha256_v1(arm.get("r10s_upright_memory", {}))
		or context.get("declaration_sha256") != _canonical_sha256_v1(arm.get("r10s_upright_declaration", {}))
		or context.get("semantic_step") != completed_global_step + 1):
		return {"ok": false, "failure_code": "R10S_APPLY_UPRIGHT_SOURCE_CROSSED"}
	# Apply the original R10R V20/V12/V7 control through the unchanged motor applier.
	var applied := super._apply_recovery_control_v1(arm_id, completed_global_step)
	if applied.get("ok") != true: return applied
	arm = _arms[arm_id]
	var tagged := UprightBridge.Source.bind_application_v1(_sdk, arm.r10s_native_receipt, arm.pending_application)
	if tagged.get("ok") != true: return tagged
	arm.pending_application = tagged.application
	arm.model[UprightBridge.Source.KEY] = tagged.model_binding
	if _r10s_first_upright_application.is_empty(): _r10s_first_upright_application = tagged.application.duplicate(true)
	_arms[arm_id] = arm
	return {"ok": true}

func _process_r10s_upright_v1(arm_id: String, global_step: int) -> Dictionary:
	var arm: Dictionary = _arms[arm_id]
	var state: Dictionary = arm.orchestrator_state
	var collection: Dictionary = arm.last_collection
	var bound: Dictionary = collection.get("epoch_result", {}).get("bound_epoch_observations", {})
	var prior_memory: Dictionary = arm.get("r10s_upright_memory", {})
	var packet := UprightBridge.step_v1(_sdk, _context, _attempt_id, bound, arm.get("r10s_upright_declaration", {}), prior_memory)
	packet["source_application"] = arm.pending_application.duplicate(true)
	packet["prior_memory"] = prior_memory.duplicate(true)
	_r10s_upright_packets.append(packet)
	if packet.get("ok") != true: return packet
	var native: Dictionary = packet.native_receipt
	var step: Dictionary = native.step
	var terminal: bool = step.next_phase in ["complete", "failed"]
	arm.r10s_upright_memory = step.memory.duplicate(true)
	arm.r10s_native_receipt = native.duplicate(true)
	arm.next_recovery_control = native.next_control.duplicate(true) if native.next_control is Dictionary else {}
	arm.last_recovery_global_semantic_step = global_step
	arm.last_recovery_terminal = terminal
	arm.last_recovery_terminal_phase = step.next_phase if terminal else ""
	arm.last_recovery_terminal_failure_code = step.memory.terminal_failure_code if step.next_phase == "failed" else ""
	arm.last_recovery_classification = step.classification.duplicate(true)
	arm.trace_rows[-1]["recovery_classification"] = step.classification.duplicate(true)
	_arms[arm_id] = arm
	var event := _build_orchestrator_event_v1(state, {
		"event_kind": "upright_recovery_controller_step", "global_semantic_step": global_step,
		"recovery_epoch_local_step": global_step - state.epoch_start_global_step,
		"control_owner": "recovery_candidate", "actuation_owner": "recovery_candidate", "recovery_actuation_applied": true,
		"application_intent_sha256": _canonical_sha256_v1(arm.pending_application),
		"energy_initializer_sha256": _arm_epoch_initializer_sha256_v1(arm),
		"stable_four_foot_stance": step.classification.stable_stance_gate,
		"recovery_controller_terminal_phase": arm.last_recovery_terminal_phase,
		"recovery_controller_terminal_reason": arm.last_recovery_terminal_failure_code,
		"r10s_native_receipt": native, "upright_prior_memory_sha256": _canonical_sha256_v1(prior_memory),
		"body_population_rebuild_count": arm.body_population_rebuild_count, "body_transform_write_count": arm.body_transform_write_count,
		"body_velocity_write_count": arm.body_velocity_write_count, "solver_reset_count": arm.solver_reset_count})
	var result := _install_orchestrator_event_v1(arm_id, state, arm.pending_application, collection, bound, event)
	if result.get("ok") == true and result.phase_after == Orchestrator.PHASE_WALKING_RESUME:
		# The next application belongs to a fresh walking task. Keep the final
		# upright observation and memory in retention, and end only its producer tag.
		_arms[arm_id].model.erase(UprightBridge.Source.KEY)
	return result

func _collect_arm_completed_step_v1(arm_id: String, global_step: int) -> Dictionary:
	var arm: Dictionary = _arms[arm_id]
	if arm.orchestrator_state.phase == R10S.PHASE_UPRIGHT:
		var selected := UprightBridge.Source.select_v1(_sdk, arm.model, arm.pending_application, global_step)
		var binding: Dictionary = arm.pending_application.get(UprightBridge.Source.KEY, {})
		if (selected.get("ok") != true or selected.get("upright_task_selected") != true
			or binding.get("memory_sha256") != _canonical_sha256_v1(arm.get("r10s_upright_memory", {}))
			or binding.get("declaration_sha256") != _canonical_sha256_v1(arm.get("r10s_upright_declaration", {}))):
			return {"ok": false, "failure_code": "R10S_PENDING_UPRIGHT_SOURCE_CROSSED"}
	return super._collect_arm_completed_step_v1(arm_id, global_step)

func _plan_next_process_isolated_frame_v1(global_step: int) -> Dictionary:
	if _arms.get(_authorized_arm_id, {}).get("orchestrator_state", {}).get("phase") != R10S.PHASE_UPRIGHT:
		return super._plan_next_process_isolated_frame_v1(global_step)
	_cost.begin_v1("plan_step/" + R10S.PHASE_UPRIGHT)
	var result := _apply_recovery_control_v1(_authorized_arm_id, global_step)
	_cost.end_v1("plan_step/" + R10S.PHASE_UPRIGHT)
	return result

func _process_completed_arm_step_v1(arm_id: String, global_step: int, active_terminal_after_step: bool) -> Dictionary:
	if _arms[arm_id].orchestrator_state.phase != R10S.PHASE_UPRIGHT:
		return super._process_completed_arm_step_v1(arm_id, global_step, active_terminal_after_step)
	_cost.begin_v1("process_step/" + R10S.PHASE_UPRIGHT)
	var result := _process_r10s_upright_v1(arm_id, global_step)
	_cost.end_v1("process_step/" + R10S.PHASE_UPRIGHT)
	return result

func _recovery_controller_for_phase_v1(phase: String) -> String:
	if phase == R10S.PHASE_UPRIGHT:
		var memory: Dictionary = _arms.get(_authorized_arm_id, {}).get("r10s_upright_memory", {})
		return UprightBridge.Source.recovery_controller_for_phase_v1(memory.get("phase", ""))
	return super._recovery_controller_for_phase_v1(phase)

func _ramp_to_hold_ready_v1(entry_memory: Dictionary, measured: Dictionary) -> bool:
	# This transfers controller ownership. The existing hold still requires
	# all five measured readiness checks for 30 consecutive samples.
	var checks: Dictionary = measured.get("readiness", {}).get("checks", {})
	return (entry_memory.get("reference_ramp_complete") == true
		and checks.get("upright") == true and checks.get("zero_bias_reference_path_feasible") == true)

func _authorized_seed_binding_v1(seed_text: String, label: String, digest: String) -> bool:
	if not _r10k_selected_v1(): return false
	var role := OS.get_environment(CHILD_ROLE_ENV)
	var descriptors: Array = _campaign_declaration.get("children", []).filter(func(child): return child.get("role") == role)
	if descriptors.size() != 1 or _campaign_declaration.get("attempt_id") != OS.get_environment(PARENT_ATTEMPT_ID_ENV): return false
	if descriptors[0].get("child_attempt_id") != OS.get_environment(ATTEMPT_ID_ENV) or descriptors[0].get("termination_nonce") != OS.get_environment(NONCE_ENV): return false
	return R10SSeed.authorized_v1(_campaign_declaration, seed_text, label, digest, role, OS.get_environment(SOURCE_COMMIT_ENV))

func _walking_prefix_profile_id_v1(segment_id: String) -> String:
	return "r10s_declared_development_prefix_phase_v1" if segment_id == "walking_prefix" else ""

func _attach_profile_seed_context_v1(report: Dictionary) -> bool:
	return R10SSeed.attach_report_context_v1(report, _campaign_declaration, _seed)

func _attach_profile_recovery_retention_v1(report: Dictionary) -> void:
	var arm: Dictionary = _arms.get(_authorized_arm_id, {})
	var kind: String = arm.get("orchestrator_state", {}).get("r10s_entry_kind", "unselected")
	report.passive_entry.schema_version = "sporespore_r10s_recovery_entry_retention_v1"
	report["r10s_partial_recovery"] = {"schema_version": "sporespore_r10s_partial_recovery_retention_v1",
		"entry_kind": kind, "declaration": arm.get("r10k_partial_declaration", {}).duplicate(true),
		"final_memory": arm.get("r10k_partial_memory", {}).duplicate(true),
		"first_partial_application": _r10k_first_partial_application.duplicate(true), "step_packets": _r10k_partial_packets.duplicate(true),
		"canonical_supervisor_synthesized": false, "source_observation_rewritten": false,
		"energy_epoch_reset": false, "physical_acceptance_authority": false, "release_authority": false}
	report["r10s_upright_recovery"] = {"schema_version": "sporespore_r10s_upright_recovery_retention_v1",
		"entry_kind": kind, "declaration": arm.get("r10s_upright_declaration", {}).duplicate(true),
		"final_memory": arm.get("r10s_upright_memory", {}).duplicate(true),
		"first_upright_application": _r10s_first_upright_application.duplicate(true), "step_packets": _r10s_upright_packets.duplicate(true),
		"canonical_supervisor_synthesized": false, "partial_supervisor_synthesized": false, "source_observation_rewritten": false,
		"energy_epoch_reset": false, "physical_acceptance_authority": false, "release_authority": false}
