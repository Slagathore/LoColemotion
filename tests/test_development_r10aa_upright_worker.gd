extends "res://tests/test_development_r10v_worker_hooks.gd"

const R10AAWorker := preload("res://sdk/adapters/godot/gdscript/r10aa_route_worker_v1.gd")
class R10AAProbe:
	extends "res://sdk/adapters/godot/gdscript/r10aa_route_worker_v1.gd"
	func _initialize() -> void:
		pass

func _profile_resource_v1() -> String:
	return "res://sdk/development/recovery_candidates/r10aa-partial-load-seeking-core-v1.json"

func _new_fixture_probe_v1() -> SceneTree:
	return R10AAProbe.new()

func _configure_fixture_probe_v1(probe: SceneTree, _resource: String) -> void:
	# Explicit component setup; this is not a launchable candidate profile.
	probe._candidate_selection = {"post_kick_controller_id": "sporespore_exact_s169_prone_to_standing_controller_v20",
		"diagnostic_schedule": {"walking_policy_id": R10AAWorker.R10AA.ROUTE}}
	probe._configuration_sha256 = SHA
