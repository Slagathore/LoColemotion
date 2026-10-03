extends "res://tests/test_development_r10k_recovery_stage.gd"
## Unchanged native recovery checks, explicitly selected V52 runtime.
func _profile_resource_v1() -> String:
	return "res://sdk/development/recovery_candidates/v53-bounded-stop-velocity-core-v1.json"
