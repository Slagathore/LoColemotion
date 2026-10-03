extends "res://sdk/trace_analysis/development_recovery_candidate_replay.gd"

const Transition := preload("res://sdk/adapters/godot/gdscript/development_walking_memory_transition_v1.gd")

func _dispatch(sdk: Object, input: Dictionary, _binding: Dictionary) -> Dictionary:
	var results := {}
	for name in input["cases"]:
		var item: Dictionary = input["cases"][name]
		results[name] = Transition.verify_v1(item["previous_output"], item["next_request"], item["local_step"])
	# Select the DLL prospectively, but replay historical rows under their own
	# retained amplitude identity. A new candidate must not relabel V23 inputs.
	var selected_id := CandidateProfile.walking_entry_id_v1(_candidate_selection, "walking_resume")
	var id: String = input["walking_report"]["development_walking_entry"]["profile_id"]
	var original := CandidateProfile.WalkingEntry.validate_report_v1(sdk, input["walking_report"], id)
	var successor := CandidateProfile.WalkingEntry.validate_report_v1(sdk, input["walking_report"], id, Transition.contract["profile_id"])
	var refused := CandidateProfile.WalkingEntry.validate_report_v1(sdk, input["walking_report"], id, "unknown")
	var selected_reader := CandidateProfile.WalkingEntry.validate_report_v1(sdk, input["walking_report"], selected_id)
	return {"ok": true, "cases": results, "original_reader": original, "successor_reader": successor,
		"retained_entry_profile_id": id, "selected_entry_profile_id": selected_id, "selected_profile_reader": selected_reader,
		"unknown_profile": refused, "correct_selection": Transition.selection_valid_v1(Transition.contract["profile_id"], selected_id),
		"crossed_entry_refused": not Transition.selection_valid_v1(Transition.contract["profile_id"], "normal_one_cycle_amplitude_ramp_with_control_trace_v1"),
		"synthetic_body_or_contact_inputs": false, "physical_outcome_predicted": false}
