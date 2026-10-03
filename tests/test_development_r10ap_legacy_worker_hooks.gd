extends "res://tests/test_development_r10v_branch_worker_hooks.gd"

func _profile_resource_v1() -> String:
	return "res://sdk/development/recovery_candidates/r10ap-progressive-headroom-v1.json"

func _configure_fixture_probe_v1(probe: SceneTree, _resource: String) -> void:
	checks["explicit_v7_runtime_without_world_authority"] = preload("res://tests/r10ap_gate_runtime.gd").select_v1()
	probe._candidate_selection = {"post_kick_controller_id": "sporespore_exact_s169_prone_to_standing_controller_v20",
		"diagnostic_schedule": {"walking_policy_id": R10V.ROUTE}}
	probe._configuration_sha256 = SHA
