extends "res://tests/test_development_r10k_worker_hooks.gd"
# gdlint: disable=max-line-length

## Export the actual worker's retained packets before destroying its isolated
## command surfaces. This fixture constructs no physics world or full report.
func _finish_r10k(probe: SceneTree, failure: Dictionary) -> void:
	var arm: Dictionary = probe._arms.get(ARM, {})
	var selection: Dictionary = probe._candidate_selection.duplicate(true)
	if not _legacy:
		selection.diagnostic_schedule["limits"] = {"maximum_precondition_steps": 320, "walking_prefix_steps": 30,
			"interaction_steps": 1, "maximum_passive_descent_steps": 240, "after_interaction_steps": 3160, "maximum_steps_per_child": 3512}
	var binding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(selection.worker_selection.binding))
	var retained := {"schema_version": selection.retention_schema if _legacy else "sporespore_r10k_recovery_entry_retention_v1",
		"candidate_profile": selection.candidate_profile, "runtime_binding": binding,
		"setup_controller_id": Route.RECOVERY_CONTROLLER_V6_ID, "post_kick_controller_id": selection.post_kick_controller_id,
		"post_kick_controller_context": probe._candidate_context, "entry_packets": probe._entry_packets,
		"canonical_packets": probe._canonical_packets, "orchestrator_transitions": probe._entry_transitions,
		"first_recovery_owned_application": probe._first_recovery_application,
		"maximum_passive_descent_steps": 240, "after_interaction_steps": 480 if _legacy else 3160,
		"canonical_initialization_permitted_before_prone": false, "energy_epoch_reset_permitted_at_handoff": false,
		"physical_acceptance_authority": false, "release_authority": false}
	var input := {"schema_version": selection.input_schema, "context": probe._context,
		"initial_state": probe._entry_transitions[0].state_before if not probe._entry_transitions.is_empty() else {},
		"final_state": arm.get("orchestrator_state", {}), "retention": retained}
	if not _legacy:
		input["partial_retention"] = {"schema_version": "sporespore_r10k_partial_recovery_retention_v1",
			"entry_kind": arm.get("orchestrator_state", {}).get("r10k_entry_kind", "unselected"),
			"declaration": arm.get("r10k_partial_declaration", {}), "final_memory": arm.get("r10k_partial_memory", {}),
			"first_partial_application": probe._r10k_first_partial_application, "step_packets": probe._r10k_partial_packets,
			"canonical_supervisor_synthesized": false, "source_observation_rewritten": false, "energy_epoch_reset": false,
			"physical_acceptance_authority": false, "release_authority": false}
	var result := {"ok": failure.is_empty() and not checks.values().has(false), "checks": checks, "failure": failure,
		"branch": "legacy" if _legacy else "prone" if _genuine_prone else "partial", "input": input,
		"selection": selection, "expected_runtime_binding": binding, "synthetic_measurements_only": true,
		"complete_report_exercised": false, "selector_and_launcher_validation_exercised": false,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}
	var file := FileAccess.open(_output, FileAccess.WRITE)
	file.store_string(Transport.stringify(result) + "\n")
	file.close()
	Route.free_zero_world_command_surface_v1(_surface)
	probe._sdk = null
	probe.free()
	print("R10K_REPLAY_FIXTURE ", JSON.stringify({"ok": result.ok, "checks": checks.size(), "failure_keys": failure.keys()}))
	quit(0 if result.ok else 1)
