extends "res://sdk/trace_analysis/development_recovery_candidate_replay.gd"

## Explicit successor entrypoint. The original reader still defaults to strict
## whole-memory continuity and must continue to reject V23's original record.
const Transition := preload("res://sdk/adapters/godot/gdscript/development_walking_memory_transition_v1.gd")

func _selection_v1() -> Dictionary:
	var selection := super._selection_v1()
	selection["marker"] = Transition.contract["replay_marker"]
	return selection

func _dispatch(sdk: Object, input: Dictionary, binding: Dictionary) -> Dictionary:
	var report := input
	if input.get("schema_version") == _candidate_selection["report_input_schema"]:
		if not (input.get("report") is Dictionary):
			return {"ok": false, "failure_code": "TRANSITION_REPLAY_REPORT_MISSING"}
		report = input["report"]
	return Replay.replay_report_v1(sdk, report, binding, _candidate_selection["post_kick_controller_id"],
		_candidate_selection, Transition.contract["profile_id"])
