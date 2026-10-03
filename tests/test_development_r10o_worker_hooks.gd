extends "res://tests/test_development_r10k_worker_hooks.gd"
## Same synthetic native recovery cases, selected through R10O and the V52 DLL.

func _profile_resource_v1() -> String:
	return ("res://sdk/development/recovery_candidates/v55-initialized-zero-brake-core-v1.json" if _legacy
		else "res://sdk/development/recovery_candidates/r10o-v55-initialized-brake-integrated-v2.json")

func _configure_fixture_probe_v1(probe: SceneTree, resource: String) -> void:
	probe._candidate_selection = R10KWorker.CandidateProfile.load_v1({"resource": resource, "raw_sha256": "sha256:" + FileAccess.get_sha256(resource)})
	checks["actual_r10o_or_legacy_selection"] = not probe._candidate_selection.is_empty() and (not probe._r10k_selected_v1() if _legacy else probe._r10o_selected_v1() and probe._r10k_selected_v1())
	probe._configuration_sha256 = SHA
