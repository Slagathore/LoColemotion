extends "res://tests/test_development_r10k_orchestrator.gd"
## Unchanged native recovery checks, explicitly selected V52 runtime.
func _profile_resource_v1() -> String:
	return "res://sdk/development/recovery_candidates/v55-initialized-zero-brake-core-v1.json"
