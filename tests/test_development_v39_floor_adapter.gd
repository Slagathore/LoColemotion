extends "res://tests/test_development_v34_floor_adapter.gd"

func _component_profile_path_v1() -> String:
	return "res://sdk/development/recovery_candidates/v39-airborne-reference-v1.json"

func _selected_policy_id_v1() -> String:
	return Shared.Policy.AIRBORNE_POLICY_ID

func _synthetic_sequence_state_v1(adapter: RefCounted, step: int) -> Dictionary:
	var state: Dictionary = super._synthetic_sequence_state_v1(adapter, step)
	# Exercise both selector branches through the real adapter; these are
	# explicitly synthetic observations, not a measured physical trajectory.
	state.base_pose_world.position_m.y = 0.37 + 0.02 * sin(float(step) / 17.0)
	for index in range(state.ordered_contact_observations.size()):
		var contact: Dictionary = state.ordered_contact_observations[index]
		contact.presence = (step + index * 19) % 53 < 31
		contact.bears_support = contact.presence
	return state
