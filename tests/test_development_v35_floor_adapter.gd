extends "res://tests/test_development_v34_floor_adapter.gd"

func _component_profile_path_v1() -> String:
	return "res://sdk/development/recovery_candidates/v35-feasible-support-v1.json"

func _selected_policy_id_v1() -> String:
	return Shared.Policy.FEASIBLE_POLICY_ID
