extends "res://sdk/adapters/godot/gdscript/development_recovery_candidate_worker_v1.gd"
# gdlint: disable=max-line-length

## R10P changes campaign entry and publication only. Model construction, native
## V55 controls, same-body stepping, budgets and capture inherit unchanged.
const R10PSeed := preload("res://sdk/adapters/godot/gdscript/r10p_campaign_seed_v1.gd")

func _authorized_seed_binding_v1(seed_text: String, label: String, digest: String) -> bool:
	if not _r10o_selected_v1() or _candidate_selection.get("candidate_profile", {}).get("resource") != R10PSeed.CANDIDATE:
		return false
	var role := OS.get_environment(CHILD_ROLE_ENV)
	var descriptors: Array = _campaign_declaration.get("children", []).filter(func(child): return child.get("role") == role)
	if descriptors.size() != 1 or _campaign_declaration.get("attempt_id") != OS.get_environment(PARENT_ATTEMPT_ID_ENV):
		return false
	if descriptors[0].get("child_attempt_id") != OS.get_environment(ATTEMPT_ID_ENV) or descriptors[0].get("termination_nonce") != OS.get_environment(NONCE_ENV):
		return false
	return R10PSeed.authorized_v1(_campaign_declaration, seed_text, label, digest, role, OS.get_environment(SOURCE_COMMIT_ENV))

func _entry_selection_v1() -> Dictionary:
	var selected: Dictionary = super._entry_selection_v1().duplicate(true)
	selected["worker"] = R10PSeed.WORKER
	return selected

func _walking_prefix_profile_id_v1(segment_id: String) -> String:
	if segment_id != "walking_prefix": return ""
	# Exposed development identities use the existing explicit 241/243 mapping.
	# Held-out seeds 50644-50646 use the unchanged facade's seed-modulo-360 path.
	return StanceEntry.R10O.PREFIX_PROFILE if _seed in R10PSeed.DEVELOPMENT_SEEDS else ""

func _attach_entry_retention_v1(report: Dictionary) -> void:
	report["schema_version"] = _entry_selection_v1()["report_schema"]
	report["work_id"] = _entry_selection_v1()["work_id"]
	report["passive_entry"] = {"schema_version": "sporespore_development_measured_prone_entry_retention_v1",
		"walking_runtime_preflight": _entry_walking_runtime_preflight,
		"runtime_binding": _entry_runtime, "entry_packets": _entry_packets,
		"orchestrator_transitions": _entry_transitions, "canonical_packets": _canonical_packets,
		"first_recovery_owned_application": _first_recovery_application,
		"maximum_passive_descent_steps": MAX_DESCENT_STEPS,
		"after_interaction_steps": _entry_after_interaction_steps_v1(),
		"canonical_initialization_permitted_before_prone": false,
		"energy_epoch_reset_permitted_at_handoff": false,
		"physical_acceptance_authority": false, "release_authority": false}

	report["candidate_profile"] = _candidate_selection["candidate_profile"].duplicate(true)
	report["development_execution_mode"] = _candidate_mode
	report["comparative_authority"] = false
	report["baseline_reused"] = false
	if not R10PSeed.attach_report_context_v1(report, _campaign_declaration, _seed):
		report["ok"] = false
		report["failure_code"] = "R10P_CAMPAIGN_PUBLICATION_CONTEXT_INVALID"
	if CandidateProfile.WalkingPolicy.FiniteRoute.selected_v1(_walking_policy_id_v1("walking_resume")):
		report["finite_recovery_task"] = CandidateProfile.WalkingPolicy.FiniteRoute.task_boundary_v1(report, _cycle_stop_memory, _walking_policy_id_v1("walking_resume"))
	if _stance_entry_selected_v1():
		report["stance_entry"] = {"schema_version": StanceEntry.retention_schema_v1(_walking_policy_id_v1("walking_resume")),
			"readiness_rows": _entry_readiness_rows.duplicate(true), "neutral_control_rows": _neutral_control_rows.duplicate(true),
			"task_contract_sha256": "sha256:"+FileAccess.get_sha256(StanceEntry.task_path_for_v1(_walking_policy_id_v1("walking_resume"))),
			"physical_acceptance_authority": false, "release_authority": false}
		if _hold_route_selected_v1():
			report["stance_entry"]["hold_control_rows"] = _hold_control_rows.duplicate(true)
	report["passive_entry"]["schema_version"] = _candidate_selection["retention_schema"]
	report["passive_entry"]["candidate_profile"] = _candidate_selection["candidate_profile"].duplicate(true)
	report["passive_entry"]["setup_controller_id"] = RouteScript.RECOVERY_CONTROLLER_V6_ID
	report["passive_entry"]["post_kick_controller_id"] = _entry_controller_id_v1()
	report["passive_entry"]["post_kick_controller_context"] = _candidate_context.duplicate(true)
	if _r10k_selected_v1():
		var arm: Dictionary = _arms.get(_authorized_arm_id, {})
		report.passive_entry.schema_version = "sporespore_r10k_recovery_entry_retention_v1"
		report["r10k_partial_recovery"] = {"schema_version": "sporespore_r10k_partial_recovery_retention_v1",
			"entry_kind": arm.get("orchestrator_state", {}).get("r10k_entry_kind", "unselected"),
			"declaration": arm.get("r10k_partial_declaration", {}).duplicate(true),
			"final_memory": arm.get("r10k_partial_memory", {}).duplicate(true),
			"first_partial_application": _r10k_first_partial_application.duplicate(true),
			"step_packets": _r10k_partial_packets.duplicate(true),
			"canonical_supervisor_synthesized": false, "source_observation_rewritten": false,
			"energy_epoch_reset": false, "physical_acceptance_authority": false, "release_authority": false}
	if CycleStop.selected_policy_v1(_walking_policy_id_v1("walking_resume")):
		report["development_cycle_stop"] = {"schema_version": CycleStop.retention_schema_v1(_walking_policy_id_v1("walking_resume")),
			"final_memory": _cycle_stop_memory.duplicate(true), "rows": _cycle_stop_sources.duplicate(true),
			"physical_acceptance_authority": false, "release_authority": false}
	var entry_id := CandidateProfile.walking_entry_id_v1(_candidate_selection, "walking_resume")
	if not entry_id.is_empty():
		report["development_walking_entry"] = CandidateProfile.WalkingEntry.retention_v1(_walking_control_sources, entry_id)
	var contact_id := _walking_contact_profile_id_v1("walking_resume")
	if not contact_id.is_empty():
		if CandidateProfile.NativeWalkingContacts.selected_v1(contact_id):
			report["development_native_walking_contacts"] = CandidateProfile.NativeWalkingContacts.retention_v1(_walking_contact_sources)
		else:
			report["development_walking_contacts"] = CandidateProfile.WalkingContacts.retention_v1(_walking_contact_sources, contact_id)
