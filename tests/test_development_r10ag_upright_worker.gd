extends "res://tests/test_development_r10v_worker_hooks.gd"

const R10AGWorker := preload("res://sdk/adapters/godot/gdscript/r10ag_route_worker_v1.gd")
class R10AGProbe:
	extends "res://sdk/adapters/godot/gdscript/r10ag_route_worker_v1.gd"
	func _initialize() -> void:
		pass

func _profile_resource_v1() -> String:
	return "res://sdk/development/recovery_candidates/r10ag-detection-frame-load-seeking-v1.json"

func _new_fixture_probe_v1() -> SceneTree:
	return R10AGProbe.new()

func _configure_fixture_probe_v1(probe: SceneTree, _resource: String) -> void:
	checks["explicit_v7_runtime_without_world_authority"] = preload("res://tests/r10ag_gate_runtime.gd").select_v1()
	# Explicit component setup; this is not a launchable candidate profile.
	probe._candidate_selection = {"post_kick_controller_id": "sporespore_exact_s169_prone_to_standing_controller_v20",
		"diagnostic_schedule": {"walking_policy_id": R10AGWorker.R10AG.ROUTE}}
	probe._configuration_sha256 = SHA
