extends "res://tests/test_development_v34_floor_adapter.gd"

func _component_profile_path_v1() -> String:
	return "res://sdk/development/recovery_candidates/v37-reference-velocity-v1.json"

func _selected_policy_id_v1() -> String:
	return Shared.Policy.REFERENCE_POLICY_ID
