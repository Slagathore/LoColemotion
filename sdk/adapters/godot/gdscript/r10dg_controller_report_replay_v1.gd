extends RefCounted
# gdlint: disable=max-line-length
## Complete-report composition over the checked R10DG segment and hold readers.
## Neither this consumer nor its delegates construct or step a physics world.
const Segment := preload("res://sdk/adapters/godot/gdscript/r10dg_recovery_replay_v1.gd")
const CandidateProfile := Segment.CandidateProfile
const Canonical := Segment.Canonical
const Entry := Segment.Entry
const R10DG := Segment.R10DG

static func replay_report_v1(sdk: Object, report: Dictionary, expected_runtime_binding: Dictionary,
	controller_id: String = Canonical.Route.RECOVERY_CONTROLLER_V6_ID, candidate_selection: Dictionary = {}, memory_transition_profile: String = "") -> Dictionary:
	var selection := Segment.selection_v1(controller_id, candidate_selection)
	var bounds := CandidateProfile.limits_v1(candidate_selection)
	if not candidate_selection.is_empty() and not Segment._same(report.get("candidate_profile"), candidate_selection.get("candidate_profile")):
		return Segment._failure("CANDIDATE_REPORT_PROFILE_CROSSED")
	if (selection.is_empty() or not Segment._same(report.get("schema_version"), selection["worker_selection"]["report_schema"])
		or not Segment._same(report.get("work_id"), selection["worker_selection"]["work_id"])):
		return Segment._failure("REPORT_SCHEMA_OR_WORK")
	for key in ["configuration", "retained_arm", "passive_entry"]:
		if not (report.get(key) is Dictionary):
			return Segment._failure("REPORT_SOURCE_MISSING:" + key)
	for key in ["arm_id", "child_attempt_id"]:
		if not (report.get(key) is String):
			return Segment._failure("REPORT_IDENTITY_KIND:" + key)
	var arm: Dictionary = report["retained_arm"]
	var retained: Dictionary = report["passive_entry"]
	var diagnostic: Dictionary = report.get("r10dg_diagnostic_terminal", {})
	var pending := 1 if diagnostic.get("disposition") == "native_reference_entry_refusal" else 0
	# This diagnostic has no post-recovery walking, hold, upright or prone branch.
	# Its original setup and 30-command prefix remain in the complete timeline.
	for key in ["development_walking_entry", "development_native_walking_contacts", "development_cycle_stop", "stance_entry"]:
		if report.has(key): return Segment._failure("UNDECLARED_RESUME_RETENTION:" + key)
	if (not (arm.get("model_instance_id") is String) or not (arm.get("body_population_instance_sha256") is String)
		or not (arm.get("orchestrator_state") is Dictionary) or not (arm.get("trace_rows") is Array)
		or not (retained.get("orchestrator_transitions") is Array)):
		return Segment._failure("REPORT_ARM_SHAPE")
	if (not Segment._same(retained.get("maximum_passive_descent_steps"), 240)
		or not Segment._same(retained.get("after_interaction_steps"), bounds["after_interaction_steps"])
		or typeof(report.get("solver_step_count")) != TYPE_INT
		or report["solver_step_count"] < 1 or report["solver_step_count"] > bounds["maximum_steps_per_child"]
		or arm["trace_rows"].size() != report["solver_step_count"]
		or retained["orchestrator_transitions"].size() + pending != report["solver_step_count"]):
		return Segment._failure("REPORT_PROFILE_OR_STEP_POPULATION")
	var entry_index := 0
	var canonical_index := 0
	var partial_index := 0
	var upright_index := 0
	var r10v_selected := Segment._route_id_v1(candidate_selection) in [R10DG.ROUTE]
	for index in range(retained["orchestrator_transitions"].size()):
		var row: Variant = arm["trace_rows"][index]
		var transition: Variant = retained["orchestrator_transitions"][index]
		if not (row is Dictionary) or not (transition is Dictionary) or not (transition.get("event") is Dictionary):
			return Segment._failure("REPORT_STEP_SOURCE_SHAPE")
		var event: Dictionary = transition["event"]
		if (not Segment._same(row.get("global_semantic_step"), index + 1)
			or not Segment._same(row.get("arm_id"), report["arm_id"])
			or not Segment._same(row.get("application_intent_sha256"), event.get("application_intent_sha256"))
			or not Segment._same(row.get("orchestrator_phase"), event.get("source_phase"))):
			return Segment._failure("REPORT_TRACE_EVENT_LINK")
		var classification: Variant = null
		if event.get("source_phase") == Entry.PHASE_DESCENT:
			var packets: Variant = retained.get("entry_packets")
			if not (packets is Array) or entry_index >= packets.size() or not (packets[entry_index] is Dictionary):
				return Segment._failure("REPORT_ENTRY_CLASSIFICATION_SOURCE")
			classification = packets[entry_index].get("original_passive_receipt" if r10v_selected else "entry_receipt", {}).get("classification")
			entry_index += 1
		elif r10v_selected and event.get("source_phase") == R10DG.PHASE_PARTIAL:
			var packets: Variant = report.get("r10df_partial_recovery", {}).get("step_packets")
			if not (packets is Array) or partial_index >= packets.size() or not (packets[partial_index] is Dictionary):
				return Segment._failure("REPORT_PARTIAL_CLASSIFICATION_SOURCE")
			classification = packets[partial_index].get("native_receipt", {}).get("step", {}).get("classification")
			partial_index += 1
		elif r10v_selected and event.get("source_phase") == R10DG.PHASE_UPRIGHT:
			var packets: Variant = report.get("r10v_upright_recovery", {}).get("step_packets")
			if not (packets is Array) or upright_index >= packets.size() or not (packets[upright_index] is Dictionary):
				return Segment._failure("REPORT_UPRIGHT_CLASSIFICATION_SOURCE")
			classification = packets[upright_index].get("native_receipt", {}).get("step", {}).get("classification")
			upright_index += 1
		elif event.get("source_phase") in [Entry.Prior.PHASE_CONFIRM_PRONE, Entry.Prior.PHASE_POST_KICK_RECOVERY]:
			var packets: Variant = retained.get("canonical_packets")
			if not (packets is Array) or canonical_index >= packets.size() or not (packets[canonical_index] is Dictionary):
				return Segment._failure("REPORT_CANONICAL_CLASSIFICATION_SOURCE")
			classification = packets[canonical_index].get("step_receipt", {}).get("classification")
			canonical_index += 1
		if classification != null and not Segment._same(classification, row.get("recovery_classification")):
			return Segment._failure("REPORT_TRACE_CLASSIFICATION_LINK")
	var initialized := (R10DG.initialize_v1(sdk, report["child_attempt_id"], report["arm_id"],
		arm["model_instance_id"], Segment._sha(sdk, report["configuration"]), arm["body_population_instance_sha256"])
		if r10v_selected else Entry.initialize_v1(sdk, report["child_attempt_id"], report["arm_id"],
		arm["model_instance_id"], Segment._sha(sdk, report["configuration"]), arm["body_population_instance_sha256"], 240, controller_id, Segment._route_id_v1(candidate_selection)))
	if initialized.get("ok") != true:
		return Segment._failure("REPORT_INITIALIZATION")
	var context := Canonical.Route.prepare_complete_energy_context_v18(sdk, Canonical.Route.RECOVERY_CONTROLLER_V6_ID)
	if context.get("ok") != true:
		return Segment._failure("REPORT_CONTEXT")
	var result := Segment.replay_v1(sdk, {"schema_version": selection["input_schema"], "initial_state": initialized["state"],
		"final_state": arm["orchestrator_state"], "context": context, "retention": retained,
		"partial_retention": report.get("r10df_partial_recovery", {}),
		"upright_retention": report.get("r10v_upright_recovery", {}),
		"post_recovery_settling": report.get("post_recovery_settling", {}),
		"reference_packets": report.get("r10df_reference_session", {}).get("packets"),
		"diagnostic_terminal": diagnostic}, expected_runtime_binding, controller_id, candidate_selection)
	if result.get("ok") != true:
		return result
	var final_state: Dictionary = arm["orchestrator_state"]
	if final_state["precondition_recovery_step_count"] > 320 or final_state["recovery_epoch_step_count"] > bounds["after_interaction_steps"]:
		return Segment._failure("REPORT_PHASE_BUDGET")
	result["ledger_scope"]["authority_mode"] = "independent_retained_report_replay"
	result["complete_report_timeline_replayed"] = true
	if final_state.walking_resume_step_count != 0 or final_state.upright_recovery_step_count != 0 or final_state.post_kick_recovery_step_count != 0:
		return Segment._failure("UNDECLARED_RECOVERY_BRANCH")
	if pending == 1:
		var row: Dictionary = arm.trace_rows[-1]
		var pending_packet: Dictionary = retained.entry_packets[-1] if diagnostic.boundary == "passive_entry" else report.r10df_partial_recovery.step_packets[-1]
		if (row.get("global_semantic_step") != report.solver_step_count or row.get("arm_id") != report.arm_id
			or row.get("orchestrator_phase") != final_state.phase
			or row.get("application_intent_sha256") != Segment._sha(sdk, pending_packet.get("source_application"))
			or report.get("stop_reason") != "r10dg_native_reference_entry_refusal"):
			return Segment._failure("PENDING_TRACE_OR_TERMINAL")
		result["diagnostic_stop_reason"] = "native_reference_entry_refusal"
		result["recovery_completed"] = false
		return result
	if diagnostic.get("disposition") == "unexpected_entry_branch":
		if (final_state.r10v_entry_kind not in ["prone", "upright"] or diagnostic.get("entry_kind") != final_state.r10v_entry_kind
			or diagnostic.get("global_semantic_step") != report.solver_step_count or report.get("stop_reason") != "r10dg_unexpected_entry_branch"):
			return Segment._failure("UNEXPECTED_ENTRY_TERMINAL")
		result["diagnostic_stop_reason"] = "unexpected_entry_branch"
		result["recovery_completed"] = false
		return result
	if final_state.phase != R10DG.Prior.PHASE_FAILED or final_state.get("diagnostic_stop_reason", "").is_empty():
		return Segment._failure("DIAGNOSTIC_TERMINAL_MISSING")
	var terminal: Dictionary = arm.get("terminal_recovery_observation_sources", {})
	var packets: Array = report.get("r10df_partial_recovery", {}).get("step_packets", [])
	if packets.is_empty() or not Segment._same(terminal.get("bound_recovery_observations"), packets[-1].get("bound_observations")):
		return Segment._failure("FINAL_OBSERVATION_NOT_RETAINED")
	result["diagnostic_stop_reason"] = final_state.diagnostic_stop_reason
	result["recovery_completed"] = false
	return result
