extends "res://sdk/trace_analysis/development_passive_entry_replay.gd"

## Separate read-only process profile. The existing V6 CLI stays unchanged by
## default and must not silently replay V8 records or substitute its runtime.
func _selection_v1() -> Dictionary:
	var profile := Replay.RateLimited.value_v1()
	return {"binding": profile["worker_selection"]["binding"],
		"extension": profile["worker_selection"]["extension"],
		"controller_id": profile["post_kick_controller_id"], "marker": profile["replay_marker"]}
