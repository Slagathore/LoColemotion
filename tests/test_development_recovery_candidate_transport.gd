extends "res://tests/test_development_passive_entry_transport.gd"

const Profile := preload("res://sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd")

func _extension_v1() -> String:
	# Test-only environment is supplied by the stage, not used by any worker.
	var path := OS.get_environment("SPORESPORE_DEVELOPMENT_TEST_CANDIDATE")
	if path.is_empty():
		path = "sdk/development/recovery_candidates/v8_harness_v1.json"
	var resource := "res://" + path
	var selection := Profile.load_v1({"resource": resource, "raw_sha256": "sha256:" + FileAccess.get_sha256(resource)})
	return selection.get("worker_selection", {}).get("extension", "")
