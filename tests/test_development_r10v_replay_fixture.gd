extends "res://tests/test_development_r10v_worker_hooks.gd"
# gdlint: disable=max-line-length

func _profile_resource_v1() -> String:
	return "res://sdk/development/recovery_candidates/r10v-v56-post-recovery-hold-integrated-v2.json"

func _configure_fixture_probe_v1(probe: SceneTree, resource: String) -> void:
	probe._candidate_selection = R10VWorker.CandidateProfile.load_v1({"resource": resource, "raw_sha256": "sha256:" + FileAccess.get_sha256(resource)})
	probe._configuration_sha256 = SHA

func _finish_r10v(probe: SceneTree, failure: Dictionary) -> void:
	var arm: Dictionary = probe._arms.get(ARM, {})
	var selection: Dictionary = probe._candidate_selection.duplicate(true)
	var binding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(selection.worker_selection.binding))
	var retained := {"schema_version": selection.retention_schema,
		"candidate_profile": selection.candidate_profile, "runtime_binding": binding,
		"setup_controller_id": Route.RECOVERY_CONTROLLER_V6_ID, "post_kick_controller_id": selection.post_kick_controller_id,
		"post_kick_controller_context": probe._candidate_context, "entry_packets": probe._entry_packets,
		"canonical_packets": probe._canonical_packets, "orchestrator_transitions": probe._entry_transitions,
		"first_recovery_owned_application": probe._first_recovery_application,
		"maximum_passive_descent_steps": 240, "after_interaction_steps": 3400,
		"canonical_initialization_permitted_before_prone": false, "energy_epoch_reset_permitted_at_handoff": false,
		"physical_acceptance_authority": false, "release_authority": false}
	var published := {"passive_entry": retained}
	probe._attach_profile_recovery_retention_v1(published)
	var input := {"schema_version": selection.input_schema, "context": probe._context,
		"initial_state": probe._entry_transitions[0].state_before if not probe._entry_transitions.is_empty() else {},
		"final_state": arm.get("orchestrator_state", {}), "retention": retained,
		"post_recovery_settling": published.post_recovery_settling,
		"partial_retention": published.r10v_partial_recovery, "upright_retention": published.r10v_upright_recovery}
	checks["real_profile_selects_own_reader"] = selection.reader == "res://sdk/trace_analysis/r10v_recovery_replay.gd"
	checks["publication_has_distinct_tasks"] = not published.has("r10k_partial_recovery") and published.r10v_partial_recovery.step_packets.is_empty()
	var result := {"ok": failure.is_empty() and not checks.values().has(false), "checks": checks, "failure": failure,
		"branch": "upright", "input": input, "selection": selection, "expected_runtime_binding": binding,
		"synthetic_measurements_only": true, "complete_report_exercised": false, "selector_exercised": true,
		"launcher_validation_exercised": false, "world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}
	var file := FileAccess.open(_output, FileAccess.WRITE)
	file.store_string(Transport.stringify(result) + "\n")
	file.close()
	Route.free_zero_world_command_surface_v1(_surface)
	if probe._arms.get(ARM, {}).get("model", {}).has("floor"): probe._arms[ARM].model.floor.free()
	probe._sdk = null
	probe.free()
	print("R10V_REPLAY_FIXTURE ", JSON.stringify({"ok": result.ok, "checks": checks.size(), "failure_keys": failure.keys()}))
	quit(0 if result.ok else 1)
