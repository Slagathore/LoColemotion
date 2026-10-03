extends "res://tests/test_development_r10k_worker_hooks.gd"
## Same synthetic native recovery cases, selected through R10M and the V52 DLL.

func _profile_resource_v1() -> String:
	return ("res://sdk/development/recovery_candidates/v53-bounded-stop-velocity-core-v1.json" if _legacy
		else "res://sdk/development/recovery_candidates/r10m-v53-bounded-stop-integrated-v1.json")

func _configure_fixture_probe_v1(probe: SceneTree, resource: String) -> void:
	probe._candidate_selection = R10KWorker.CandidateProfile.load_v1({"resource": resource, "raw_sha256": "sha256:" + FileAccess.get_sha256(resource)})
	checks["actual_r10m_or_legacy_selection"] = not probe._candidate_selection.is_empty() and (not probe._r10k_selected_v1() if _legacy else probe._r10m_selected_v1() and probe._r10k_selected_v1())
	probe._configuration_sha256 = SHA
