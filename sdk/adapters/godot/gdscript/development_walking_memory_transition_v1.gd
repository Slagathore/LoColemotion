extends RefCounted
# gdlint: disable=max-line-length

## Pure adapter-memory operation only. No start, sample, motor or world call.
const Adapter := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const Startup := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_startup_v1.gd")
static var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_walking_memory_transition_contract_v1.json"))

static func selection_valid_v1(profile_id: String, entry_id: String) -> bool:
	return profile_id == contract["profile_id"] and Startup.phase_family_id_v1(entry_id) == contract["walking_entry_profile_id"] and "sha256:" + FileAccess.get_sha256(contract["adapter_resource"]) == contract["adapter_raw_sha256"]

static func verify_v1(previous_output: Dictionary, next_request: Dictionary, local_step: int) -> Dictionary:
	var before: Variant = previous_output.get("next_memory")
	var after: Variant = next_request.get("memory")
	var mode: Variant = next_request.get("command", {}).get("phase_progression_mode")
	var expected_mode := "clocked" if local_step < int(contract["transition_local_step"]) else "contact_gated"
	var previous_mode := "clocked" if local_step - 1 < int(contract["transition_local_step"]) else "contact_gated"
	if not (before is Dictionary) or not (after is Dictionary) or local_step < 2 or mode != expected_mode or before.get("phase_progression_mode") != previous_mode or before.get("last_semantic_step") != local_step - 1 or next_request.get("state", {}).get("semantic_step") != local_step:
		return {"ok": false, "failure_code": "DEVELOPMENT_MEMORY_TRANSITION_BOUNDARY"}
	var adapter := Adapter.new()
	adapter._memory = before.duplicate(true)
	adapter._requested_phase_progression_mode = previous_mode
	var configured := adapter._configure_phase_progression_mode(mode)
	if configured.get("ok") != true or Transport.stringify(adapter._memory) != Transport.stringify(after):
		return {"ok": false, "failure_code": "DEVELOPMENT_MEMORY_TRANSITION_CONTENT"}
	return {"ok": true, "adapter_mode_transition_count": 1 if mode != previous_mode else 0,
		"world_build_count": 0, "native_physics_read_count": 0, "solver_step_count": 0}
