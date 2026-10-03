extends "res://sdk/trace_analysis/development_recovery_candidate_replay.gd"

## Exercise the real GDScript selector without constructing a world.
func _dispatch(_sdk: Object, input: Dictionary, _binding: Dictionary) -> Dictionary:
	var cases := {}
	for name in input["schedules"]:
		cases[name] = CandidateProfile.walking_replay_selection_valid_v1(input["schedules"][name])
	var saved := CandidateProfile._walking_replay_contract.duplicate(true)
	CandidateProfile._walking_replay_contract["transition_contract_sha256"] = "sha256:" + "0".repeat(64)
	var drift_refused := not CandidateProfile.walking_replay_selection_valid_v1(_candidate_selection["diagnostic_schedule"])
	CandidateProfile._walking_replay_contract = saved
	return {"ok": true, "cases": cases, "contract_drift_refused": drift_refused,
		"memory_transition_profile_id": CandidateProfile.walking_memory_transition_id_v1(_candidate_selection),
		"world_build_count": 0, "native_physics_read_count": 0, "solver_step_count": 0}
