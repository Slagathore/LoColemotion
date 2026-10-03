extends "res://sdk/adapters/godot/gdscript/r10v_recovery_worker_v1.gd"
# gdlint: disable=max-line-length

## New V28 partial worker; original upright, prone, setup and walking remain
## inherited. Structural arm slots retain their original names; native receipts
## and orchestrator identities belong exclusively to R10AP.
const R10AP := preload("res://sdk/explorer/phase74_diagnostic/r10ap_recovery_orchestrator_v1.gd")
const PartialBridge := preload("res://sdk/adapters/godot/gdscript/r10ap_partial_recovery_stage_v1.gd")

func _r10k_selected_v1() -> bool:
	# Reuse original partial/prone worker hooks only under this own route.
	return _candidate_selection.get("diagnostic_schedule", {}).get("walking_policy_id") == R10AP.ROUTE

func _initialize_orchestrator_v1(arm_id: String, model_id: String, population: String) -> Dictionary:
	return R10AP.initialize_v1(_sdk, _attempt_id, arm_id, model_id, _configuration_sha256, population)

func _build_orchestrator_event_v1(state: Dictionary, fields: Dictionary) -> Dictionary:
	# These are fresh event inputs from shared hooks, not retained old events.
	var own := fields.duplicate(true)
	if own.has("r10k_native_receipt"):
		if own.has("r10v_native_receipt"): return {"ok": false, "failure_code": "R10AP_COMPETING_NATIVE_EVENT"}
		own["r10v_native_receipt"] = own.r10k_native_receipt
		own.erase("r10k_native_receipt")
	if state.phase == R10AP.PHASE_UPRIGHT and own.get("recovery_controller_terminal_phase") == "complete":
		if _kicked_entry_checked: return {"ok": false, "failure_code": "R10AP_REPEATED_COMPLETION_READINESS"}
		var measured := _entry_measurement_v1(_arms[state.arm_id])
		if measured.get("ok") != true: return measured
		_kicked_entry_checked = true
		_post_recovery_hold_entry_source = measured.duplicate(true)
		_entry_readiness_rows.append({"role": state.arm_id, "purpose": "post_recovery_entry",
			"global_semantic_step": own.global_semantic_step, "source": measured.duplicate(true)})
		own.post_recovery_readiness = measured.readiness
		own.post_recovery_readiness_source_sha256 = _canonical_sha256_v1(measured)
	return R10AP.build_event_v1(_sdk, state, own)

func _advance_orchestrator_step_v1(state: Dictionary, event: Dictionary) -> Dictionary:
	var result := R10AP.advance_v1(_sdk, state, event)
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
		arm["r10v_upright_declaration"] = {}
		arm["r10v_upright_memory"] = {}
		arm["r10v_native_receipt"] = {}
		_arms[state.arm_id] = arm
	return result

func _process_descent_v1(arm_id: String, global_step: int) -> Dictionary:
	var arm: Dictionary = _arms[arm_id]
	var state: Dictionary = arm.orchestrator_state
	var collection: Dictionary = arm.last_collection
	var bound: Dictionary = collection.get("epoch_result", {}).get("bound_epoch_observations", {})
	var packet := PartialBridge.entry_v1(_sdk, _context, _attempt_id, bound, arm.get("passive_entry_state", {}))
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
			or not arm.get("r10k_partial_memory", {}).is_empty() or not arm.get("r10v_upright_memory", {}).is_empty()):
			return {"ok": false, "failure_code": "R10AP_RECOVERY_REINITIALIZATION"}
		if kind == "prone":
			if not (original.get("canonical_memory") is Dictionary): return {"ok": false, "failure_code": "R10AP_PRONE_MEMORY_MISSING"}
			arm.recovery_memory = original.canonical_memory.duplicate(true)
			arm.passive_entry_handoff_receipt = original.duplicate(true)
			arm["first_post_entry_application_pending"] = true
		elif kind == "partial":
			var entry: Dictionary = packet.original_control_receipt.entry
			arm.r10k_partial_declaration = entry.partial_declaration.duplicate(true)
			arm.r10k_partial_memory = entry.partial_memory.duplicate(true)
			arm.r10k_native_receipt = packet.native_receipt.duplicate(true)
			arm.next_recovery_control = packet.native_receipt.initial_partial_control.duplicate(true)
		else:
			arm.r10v_upright_declaration = packet.original_entry_control_receipt.entry.upright_declaration.duplicate(true)
			arm.r10v_upright_memory = packet.original_entry_control_receipt.entry.upright_memory.duplicate(true)
			arm.r10v_native_receipt = packet.original_entry_control_receipt.duplicate(true)
			arm.next_recovery_control = packet.original_entry_control_receipt.initial_upright_control.duplicate(true)
	_arms[arm_id] = arm
	var event := _build_orchestrator_event_v1(state, {
		"event_kind": "passive_entry_observation", "global_semantic_step": global_step,
		"recovery_epoch_local_step": global_step - state.epoch_start_global_step,
		"control_owner": "none", "actuation_owner": "none", "no_actuation_requested": true,
		"application_intent_sha256": _canonical_sha256_v1(arm.pending_application),
		"energy_initializer_sha256": _arm_epoch_initializer_sha256_v1(arm),
		"prone_sample": original.classification.entry_prone_gate, "stable_four_foot_stance": original.classification.stable_stance_gate,
		"passive_entry_receipt_sha256": _canonical_sha256_v1(original), "passive_entry_status": original.memory.status,
		"canonical_initialization_count": original.canonical_initialization_count, "r10v_native_receipt": packet.native_receipt,
		"body_population_rebuild_count": arm.body_population_rebuild_count, "body_transform_write_count": arm.body_transform_write_count,
		"body_velocity_write_count": arm.body_velocity_write_count, "solver_reset_count": arm.solver_reset_count})
	return _install_orchestrator_event_v1(arm_id, state, arm.pending_application, collection, bound, event)

func _partial_control_context_v1(native: Dictionary) -> Dictionary:
	return PartialBridge.Source.control_context_v1(_sdk, native)

func _bind_partial_application_v1(native: Dictionary, application: Dictionary) -> Dictionary:
	return PartialBridge.Source.bind_application_v1(_sdk, native, application)

func _select_partial_source_v1(model: Dictionary, application: Dictionary, step: int) -> Dictionary:
	return PartialBridge.Source.select_v1(_sdk, model, application, step)

func _partial_source_key_v1() -> String:
	return PartialBridge.Source.KEY

func _partial_step_packet_v1(bound: Dictionary, declaration: Dictionary, memory: Dictionary) -> Dictionary:
	return PartialBridge.step_v1(_sdk, _context, _attempt_id, bound, declaration, memory)

func _recovery_controller_for_phase_v1(phase: String) -> String:
	if phase == R10AP.PHASE_PARTIAL:
		return PartialBridge.Source.RECOVERY
	return super._recovery_controller_for_phase_v1(phase)

func _authorized_seed_binding_v1(_seed_text: String, _label: String, _digest: String) -> bool:
	# This source component grants no launch authority. A distinct prospective
	# route profile and launcher/reader safety integration must enable execution.
	return false

func _attach_profile_seed_context_v1(_report: Dictionary) -> bool:
	return false

func _attach_profile_recovery_retention_v1(report: Dictionary) -> void:
	super._attach_profile_recovery_retention_v1(report)
	# Fresh report assembly only; never transform a retained historical report.
	report.passive_entry.schema_version = "sporespore_r10ap_recovery_entry_retention_v1"
	var partial: Dictionary = report.r10v_partial_recovery
	partial.schema_version = "sporespore_r10ap_partial_recovery_retention_v1"
	partial["control_composition_id"] = PartialBridge.Source.COMPOSITION
	report["r10ap_partial_recovery"] = partial
	report.erase("r10v_partial_recovery")
