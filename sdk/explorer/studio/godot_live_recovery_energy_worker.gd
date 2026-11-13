extends "res://sdk/explorer/studio/godot_live_recovery_epoch_worker.gd"
const LiveEnergy := preload("res://sdk/adapters/godot/gdscript/live_recovery_energy_v1.gd")
const EnergyChecks := preload("res://sdk/explorer/studio/test_live_recovery_energy.gd")
var _energy_gate := {}
var _energy_state := {}
var _energy_rows: Array = []
var _energy_cost_us := 0

func _verify_l15_prepared_context_before_world_v1() -> bool:
	_energy_gate = EnergyChecks.run(_sdk, _context)
	if _energy_gate.get("ok") != true: _abort("LIVE_ENERGY_ZERO_WORLD_REFUSED", _energy_gate); return false
	return super._verify_l15_prepared_context_before_world_v1()

func _observe_live_completed_step_v1(model: Dictionary, completed_step: int, native_sequence: int) -> Dictionary:
	var original := super._observe_live_completed_step_v1(model,completed_step,native_sequence)
	if original.get("ok") != true or completed_step < 300 or completed_step > 302: return original
	var started := Time.get_ticks_usec()
	var row: Dictionary = _epoch_rows.back()
	var result: Dictionary
	if _energy_state.is_empty():
		result = LiveEnergy.begin_v1(_sdk,_context,_epoch_state)
		_energy_rows.append({"begin":result})
	else:
		var events: Array = []
		for event in _live_events:
			if event.apply_at_frame == completed_step: events.append(event)
		var sources := LiveEnergy.capture_sources_v1(_sdk,_context,model,row.capture,false,events)
		if sources.get("ok") != true: _energy_rows.append({"sources":sources}); return sources
		result = LiveEnergy.advance_v1(_sdk,_energy_state,row.transition,sources)
		_energy_rows.append({"sources":sources,"transition":result})
	_energy_cost_us += Time.get_ticks_usec()-started
	if result.get("ok") == true: _energy_state = result.get("state_after",result.get("state",{}))
	return result

func _send(value: Dictionary) -> void:
	if value.get("message_type") == "completed":
		var gate := _energy_gate.duplicate(true)
		if gate.has("positive_fixture"):
			gate["positive_fixture_retained"] = _retain_epoch_json_v1("live-recovery-energy-controls.json", [gate.positive_fixture])
			gate.erase("positive_fixture")
		var retained := {}
		if not _energy_rows.is_empty(): retained = _retain_epoch_json_v1("live-recovery-energy.json",_energy_rows)
		value.summary["live_recovery_energy"] = {"zero_world":gate,"retained":retained,
			"increment_count":_energy_state.get("increment_count",0),"collection_and_projection_us":_energy_cost_us,
			"recovery_command_emitted":false,"physical_acceptance_authority":false,"release_authority":false}
		if not _check_only: value.ok = value.get("ok") == true and _energy_rows.size() == 3 and _energy_state.get("increment_count") == 2
	super._send(value)
