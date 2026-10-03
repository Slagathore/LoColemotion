extends "res://sdk/trace_analysis/development_passive_entry_replay.gd"

## Explicit arguments: report, repository profile resource, exact profile hash.
## No selection from inherited process environment or from untrusted report data.
const CandidateProfile := preload("res://sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd")
const R10RReplay := preload("res://sdk/adapters/godot/gdscript/r10r_recovery_replay_v1.gd")
var _candidate_selection: Dictionary = {}

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		_finish({"ok": false, "failure_code": "CANDIDATE_REPLAY_ARGUMENTS"})
		return
	_candidate_selection = CandidateProfile.load_v1({"resource": args[1], "raw_sha256": args[2]})
	if _candidate_selection.is_empty() or _candidate_selection.get("diagnostic_schedule", {}).get("walking_policy_id") != CandidateProfile.WalkingPolicy.R10R.ID:
		_finish({"ok": false, "failure_code": "CANDIDATE_REPLAY_PROFILE"})
		return
	super._run()

func _input_arguments_v1() -> PackedStringArray:
	return PackedStringArray([OS.get_cmdline_user_args()[0]])

func _selection_v1() -> Dictionary:
	var worker: Dictionary = _candidate_selection.get("worker_selection", {})
	return {"binding": worker.get("binding", ""), "extension": worker.get("extension", ""),
		"controller_id": _candidate_selection.get("post_kick_controller_id", ""),
		"marker": CandidateProfile.contract_v1()["replay_marker"]}

func _dispatch(sdk: Object, input: Dictionary, binding: Dictionary) -> Dictionary:
	var controller_id: String = _candidate_selection["post_kick_controller_id"]
	var transition_id := CandidateProfile.walking_memory_transition_id_v1(_candidate_selection)
	if input.get("schema_version") == _candidate_selection["worker_selection"]["report_schema"]:
		return R10RReplay.replay_report_v1(sdk, input, binding, controller_id, _candidate_selection, transition_id)
	if input.get("schema_version") == _candidate_selection["report_input_schema"]:
		if not (input.get("report") is Dictionary):
			return {"ok": false, "failure_code": "CANDIDATE_REPLAY_REPORT_MISSING"}
		return R10RReplay.replay_report_v1(sdk, input["report"], binding, controller_id, _candidate_selection, transition_id)
	return R10RReplay.replay_v1(sdk, input, binding, controller_id, _candidate_selection)
