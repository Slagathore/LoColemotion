extends "res://tests/test_development_r10k_recovery_stage.gd"
## Unchanged native recovery checks, explicitly selected V52 runtime.
func _profile_resource_v1() -> String:
	return "res://sdk/development/recovery_candidates/v54-zero-velocity-brake-core-v1.json"
