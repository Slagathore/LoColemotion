extends RefCounted
# gdlint: disable=max-line-length

## Worker-side finite command session. Receipts remain original native values.
## A stopped or refused session cannot supply another motor command.
const Bridge := preload("res://sdk/adapters/godot/gdscript/r10de_partial_recovery_stage_v1.gd")
const Source := Bridge.Source
const Transport := Bridge.Transport
const ENTRY := "sporespore_r10dd_native_reference_entry_control_request_v1"
const STEP := "sporespore_r10dd_native_reference_step_control_request_v1"
const PACKET := "sporespore_r10de_reference_worker_packet_v1"

static func execute_v1(sdk: Object, request: Dictionary, prior: Dictionary = {}) -> Dictionary:
	var packet := {"schema_version": PACKET, "ok": false, "action": "refuse",
		"failure_code": "", "call": null, "native_receipt": null, "next_control": null,
		"task_memory": null, "reference_memory": null, "diagnostic_stop_reason": null,
		"prior_packet_sha256": Source._sha(sdk, prior),
		"world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}
	var method := ""
	if request.get("schema_version") == ENTRY:
		if not prior.is_empty(): return _refuse(packet, "REENTRY")
		method = "recovery_r10dd_partial_entry_control_v1_json"
	elif request.get("schema_version") == STEP:
		if (prior.get("schema_version") != PACKET or prior.get("ok") != true or prior.get("action") != "command"
			or not (request.get("step") is Dictionary) or not (request.step.get("observation") is Dictionary)
			or not (prior.get("next_control") is Dictionary)):
			return _refuse(packet, "PRIOR_NOT_ACTIVE")
		if (not _same(request.step.get("memory"), prior.get("task_memory"))
			or not _same(request.get("reference_memory"), prior.get("reference_memory"))
			or request.step.observation.get("semantic_step") != prior.next_control.semantic_step + 1
			or request.step.observation.get("applied_actuation", {}).get("command_sha256") != prior.next_control.command_sha256):
			return _refuse(packet, "MEMORY_CLOCK_OR_COMMAND_CHAIN")
		method = "recovery_r10dd_partial_step_control_v1_json"
	else:
		return _refuse(packet, "REQUEST_SCHEMA")
	packet.call = Bridge.call_v1(sdk, method, request)
	if packet.call.get("ok") != true: return _refuse(packet, "NATIVE_REFUSED")
	var receipt: Dictionary = packet.call.value
	packet.native_receipt = receipt.duplicate(true)
	packet.reference_memory = receipt.get("reference_memory")
	if request.schema_version == ENTRY:
		packet.task_memory = receipt.get("original_entry_control", {}).get("original_control", {}).get("entry", {}).get("partial_memory")
	else:
		packet.task_memory = receipt.get("step", {}).get("memory")
		var reason: Variant = receipt.get("diagnostic_stop_reason")
		if reason != null:
			if not stop_valid_v1(receipt): return _refuse(packet, "STOP_RECEIPT")
			packet.action = "stop"
			packet.diagnostic_stop_reason = reason
			packet.ok = true
			return packet
	var control := Source.control_context_v1(sdk, receipt)
	if control.get("ok") != true: return _refuse(packet, "COMMAND_RECEIPT")
	packet.next_control = control.control.duplicate(true)
	packet.action = "command"
	packet.ok = true
	return packet

static func stop_valid_v1(receipt: Dictionary) -> bool:
	if (receipt.get("schema_version") != "sporespore_r10dd_native_reference_step_control_receipt_v1"
		or receipt.get("control_composition_id") != Source.COMPOSITION
		or receipt.get("next_control") != null or receipt.get("next_reference") != null
		or not (receipt.get("step", {}).get("memory") is Dictionary)
		or not (receipt.get("reference_memory") is Dictionary)
		or receipt.reference_memory.get("finished") != true): return false
	for flag in ["original_observation_rewritten", "canonical_supervisor_synthesized", "physical_acceptance_authority", "release_authority"]:
		if receipt.get(flag) != false: return false
	if receipt.get("world_build_count") != 0 or receipt.get("solver_step_count") != 0: return false
	var memory: Dictionary = receipt.step.memory
	match receipt.get("diagnostic_stop_reason"):
		"finite_reference_exhausted_not_recovery_completion":
			return (memory.get("last_semantic_step") == 749 and memory.get("phase") == "raise_body"
				and memory.get("phase_steps_observed") == 236 and receipt.step.get("partial_fall_standing_complete") == false
				and receipt.reference_memory.get("last_planned_reference_tick") == 236)
		"original_supervisor_phase_transition":
			return memory.get("phase") != "raise_body"
	return false

## Independently reissue retained native requests, then rebuild each worker
## decision. Finalization requires an explicit terminal diagnostic outcome.
static func replay_v1(sdk: Object, packets: Array, require_terminal: bool = true) -> Dictionary:
	var prior := {}
	var count := 0
	for value in packets:
		if not (value is Dictionary) or not (value.get("call") is Dictionary): return {"ok": false, "failure_code": "R10DE_REPLAY_CALL_MISSING"}
		var call: Dictionary = value.call
		if not (call.get("request") is Dictionary) or not (call.request.get("utf8_text") is String): return {"ok": false, "failure_code": "R10DE_REPLAY_REQUEST_MISSING"}
		if not _same(call.request, Bridge.Bytes.bytes_v1(call.request.utf8_text)): return {"ok": false, "failure_code": "R10DE_REPLAY_REQUEST_BYTES"}
		var request: Variant = sdk.decode_exact_json_v1(call.request.utf8_text)
		if not (request is Dictionary): return {"ok": false, "failure_code": "R10DE_REPLAY_REQUEST_JSON"}
		var replayed := execute_v1(sdk, request, prior)
		if not _same(value, replayed): return {"ok": false, "failure_code": "R10DE_REPLAY_PACKET_MISMATCH"}
		prior = replayed
		count += 1
	if count == 0 or require_terminal and prior.get("action") not in ["stop", "refuse"]: return {"ok": false, "failure_code": "R10DE_REPLAY_INCOMPLETE"}
	return {"ok": true, "packet_count": count, "final_action": prior.action,
		"diagnostic_stop_reason": prior.diagnostic_stop_reason, "final_packet_sha256": Source._sha(sdk, prior),
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}

static func _same(a: Variant, b: Variant) -> bool:
	return Transport.stringify(a) == Transport.stringify(b)

static func _refuse(packet: Dictionary, reason: String) -> Dictionary:
	packet.failure_code = "R10DE_REFERENCE_SESSION_" + reason
	return packet
