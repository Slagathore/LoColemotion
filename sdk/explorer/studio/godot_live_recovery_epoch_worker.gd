extends "res://sdk/explorer/studio/godot_live_walking_worker.gd"
## Production callback entry for the fresh observer. The bounded route probe
## commissions source continuity before any recovery command is permitted.
const LiveEpoch := preload("res://sdk/adapters/godot/gdscript/live_recovery_epoch_v1.gd")
const EpochChecks := preload("res://sdk/explorer/studio/test_live_recovery_epoch.gd")
var _epoch_gate := {}
var _epoch_state := {}
var _epoch_rows: Array = []
var _epoch_capture_us := 0

func _verify_l15_prepared_context_before_world_v1() -> bool:
	_epoch_gate = EpochChecks.run(_sdk)
	if _epoch_gate.get("ok") != true: _abort("LIVE_EPOCH_ZERO_WORLD_REFUSED", _epoch_gate); return false
	return super._verify_l15_prepared_context_before_world_v1()

func _observe_live_completed_step_v1(model: Dictionary, completed_step: int, native_sequence: int) -> Dictionary:
	if completed_step < 300 or completed_step > 302: return {"ok": true}
	var started := Time.get_ticks_usec()
	var captured := LiveEpoch.capture_v1(_sdk, model, completed_step, native_sequence)
	_epoch_capture_us += Time.get_ticks_usec() - started
	if captured.get("ok") != true: _epoch_rows.append(captured); return captured
	var observed: Dictionary
	if _epoch_state.is_empty():
		var trigger := {"schema_version": "sporespore_live_recovery_epoch_route_trigger_v1",
			"session_id": _diagnostic.id, "completed_global_step": completed_step,
			"reason": "prospective_boundary_route_probe", "fall_detection_claimed": false}
		observed = LiveEpoch.begin_v1(_sdk, captured, _diagnostic.id + "_epoch_1", LiveEpoch.World._sha256(_sdk, trigger))
		_epoch_rows.append({"capture": captured, "trigger": trigger, "transition": observed})
	else:
		observed = LiveEpoch.advance_v1(_sdk, _epoch_state, captured)
		_epoch_rows.append({"capture": captured, "transition": observed})
	if observed.get("ok") == true: _epoch_state = observed.get("state_after", observed.get("state", {}))
	return observed

func _send(value: Dictionary) -> void:
	if value.get("message_type") == "completed":
		# The display protocol rounds numbers. Keep reader controls in the same
		# full-precision transport as the native observations.
		var gate := _epoch_gate.duplicate(true)
		if gate.has("positive_rows"):
			gate["positive_rows_retained"] = _retain_epoch_json_v1("live-recovery-epoch-controls.json", gate.positive_rows)
			gate.erase("positive_rows")
		var retained := {}
		if not _epoch_rows.is_empty():
			retained = _retain_epoch_json_v1("live-recovery-epoch.json", _epoch_rows)
		value.summary["live_recovery_epoch"] = {"zero_world": gate, "retained": retained,
			"observed_pair_count": _epoch_state.get("observed_pair_count", 0), "capture_us": _epoch_capture_us,
			"complete_recovery_energy_partition": false, "fall_detection_claimed": false,
			"recovery_command_emitted": false, "physical_acceptance_authority": false, "release_authority": false}
		if not _check_only: value.ok = value.get("ok") == true and _epoch_rows.size() == 3 and _epoch_state.get("observed_pair_count") == 2
	super._send(value)

func _retain_epoch_json_v1(name: String, rows: Array) -> Dictionary:
	var path: String = _diagnostic.output.get_base_dir().path_join(name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return {"ok": false, "failure_code": "EPOCH_RETENTION_FAILED"}
	file.store_string(JsonTransportScript.stringify(LiveEpoch.json_safe_v1(rows))); file.close()
	return {"path": path, "sha256": FileAccess.get_sha256(path), "rows": rows.size()}
