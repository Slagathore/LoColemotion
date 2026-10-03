extends RefCounted
# gdlint: disable=max-line-length
## Complete-report composition over the checked R10AJ segment and hold readers.
## Neither this consumer nor its delegates construct or step a physics world.
const Segment := preload("res://sdk/adapters/godot/gdscript/r10aj_recovery_replay_v1.gd")
const StanceEntryReplay := preload("res://sdk/adapters/godot/gdscript/r10aj_stance_entry_replay_v1.gd")
const CandidateProfile := Segment.CandidateProfile
const Canonical := Segment.Canonical
const Entry := Segment.Entry
const R10AJ := Segment.R10AJ

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
	var start_id := CandidateProfile.walking_start_id_v1(candidate_selection, "walking_resume")
	var start_replay := CandidateProfile.WalkingStart.validate_report_v1(report, start_id)
	if start_replay.get("ok") != true:
		return start_replay
	var policy_replay := CandidateProfile.WalkingPolicy.validate_report_v1(report, Segment._route_id_v1(candidate_selection))
	if policy_replay.get("ok") != true:
		return policy_replay
	if not CandidateProfile.WalkingFrame.report_selection_valid_v1(arm,
		CandidateProfile.walking_frame_id_v1(candidate_selection, "walking_resume"), Segment._route_id_v1(candidate_selection)):
		return Segment._failure("REPORT_WALKING_FRAME_SELECTION_CROSSED")
	if (not (arm.get("model_instance_id") is String) or not (arm.get("body_population_instance_sha256") is String)
		or not (arm.get("orchestrator_state") is Dictionary) or not (arm.get("trace_rows") is Array)
		or not (retained.get("orchestrator_transitions") is Array)):
		return Segment._failure("REPORT_ARM_SHAPE")
	if (not Segment._same(retained.get("maximum_passive_descent_steps"), 240)
		or not Segment._same(retained.get("after_interaction_steps"), bounds["after_interaction_steps"])
		or typeof(report.get("solver_step_count")) != TYPE_INT
		or report["solver_step_count"] < 1 or report["solver_step_count"] > bounds["maximum_steps_per_child"]
		or arm["trace_rows"].size() != report["solver_step_count"]
		or retained["orchestrator_transitions"].size() != report["solver_step_count"]):
		return Segment._failure("REPORT_PROFILE_OR_STEP_POPULATION")
	var stance_entry_replay := StanceEntryReplay.validate_report_v1(sdk, report, Segment._route_id_v1(candidate_selection))
	if stance_entry_replay.get("ok") != true: return stance_entry_replay
	var walking_replay := CandidateProfile.WalkingEntry.validate_report_v1(sdk, report,
		CandidateProfile.walking_entry_id_v1(candidate_selection, "walking_resume"), memory_transition_profile,
		Segment._route_id_v1(candidate_selection))
	if walking_replay.get("ok") != true:
		return walking_replay
	var contact_id := CandidateProfile.walking_contact_id_v1(candidate_selection, "walking_resume")
	if not CandidateProfile.NativeWalkingContacts.selected_v1(contact_id) and report.has("development_native_walking_contacts"):
		return Segment._failure("UNSELECTED_NATIVE_CONTACT_RETENTION")
	var contact_replay := (CandidateProfile.NativeWalkingContacts.validate_report_v1(sdk, report, Segment._route_id_v1(candidate_selection))
		if CandidateProfile.NativeWalkingContacts.selected_v1(contact_id)
		else CandidateProfile.WalkingContacts.validate_report_v1(report, contact_id))
	if contact_replay.get("ok") != true:
		return contact_replay
	var entry_index := 0
	var canonical_index := 0
	var partial_index := 0
	var upright_index := 0
	var r10v_selected := Segment._route_id_v1(candidate_selection) in [R10AJ.ROUTE]
	for index in range(arm["trace_rows"].size()):
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
		elif r10v_selected and event.get("source_phase") == R10AJ.PHASE_PARTIAL:
			var packets: Variant = report.get("r10aj_partial_recovery", {}).get("step_packets")
			if not (packets is Array) or partial_index >= packets.size() or not (packets[partial_index] is Dictionary):
				return Segment._failure("REPORT_PARTIAL_CLASSIFICATION_SOURCE")
			classification = packets[partial_index].get("native_receipt", {}).get("step", {}).get("classification")
			partial_index += 1
		elif r10v_selected and event.get("source_phase") == R10AJ.PHASE_UPRIGHT:
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
	var initialized := (R10AJ.initialize_v1(sdk, report["child_attempt_id"], report["arm_id"],
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
		"partial_retention": report.get("r10aj_partial_recovery", {}),
		"upright_retention": report.get("r10v_upright_recovery", {}),
		"post_recovery_settling": report.get("post_recovery_settling", {})}, expected_runtime_binding, controller_id, candidate_selection)
	if result.get("ok") != true:
		return result
	var final_state: Dictionary = arm["orchestrator_state"]
	if final_state["precondition_recovery_step_count"] > 320 or final_state["recovery_epoch_step_count"] > bounds["after_interaction_steps"]:
		return Segment._failure("REPORT_PHASE_BUDGET")
	result["ledger_scope"]["authority_mode"] = "independent_retained_report_replay"
	result["complete_report_timeline_replayed"] = true
	if stance_entry_replay.get("selected") == true: result["stance_entry_replay"] = stance_entry_replay
	if CandidateProfile.WalkingPolicy.FiniteRoute.selected_v1(Segment._route_id_v1(candidate_selection)):
		var task := CandidateProfile.WalkingPolicy.FiniteRoute.task_boundary_v1(report, walking_replay.get("cycle_stop_final_memory", {}), Segment._route_id_v1(candidate_selection))
		if not Segment._same(report.get("finite_recovery_task"), task) or task["role_and_budget_valid"] != true:
			return Segment._failure("FINITE_TASK_BOUNDARY_OR_ROLE_BUDGET")
		result["finite_recovery_task"] = task

	if not start_id.is_empty():
		result["walking_start_validation"] = start_replay
	if not Segment._route_id_v1(candidate_selection).is_empty():
		result["walking_policy_validation"] = policy_replay
	if not CandidateProfile.walking_entry_id_v1(candidate_selection, "walking_resume").is_empty():
		result["walking_control_replay"] = walking_replay
	if not CandidateProfile.walking_contact_id_v1(candidate_selection, "walking_resume").is_empty():
		result["walking_contact_validation"] = contact_replay
	return result
