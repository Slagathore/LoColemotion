extends RefCounted
# gdlint: disable=max-line-length

## Production source bridge. Retains supplied source and every native call.
## It never creates a world, reads the solver, applies a motor or resets energy.
const Prior := preload("res://sdk/adapters/godot/gdscript/development_passive_entry_stage_v1.gd")
const Original := preload("res://sdk/adapters/godot/gdscript/r10k_partial_recovery_stage_v1.gd")
const Source := preload("res://sdk/adapters/godot/gdscript/r10q_upright_task_source_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const Bytes := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_transport_v1.gd")
const PROFILE := "sporespore_r10k_exact_s169_prone_thresholds_v1"
const STATE := "sporespore_r10q_upright_entry_bridge_state_v1"

static func entry_v1(sdk: Object, context: Dictionary, attempt_id: String, bound: Dictionary, prior: Dictionary = {}) -> Dictionary:
	var packet := _packet("entry", attempt_id, bound)
	var source := source_v1(sdk, context, attempt_id, bound)
	if source.get("ok") != true: return _refuse(packet, source.get("failure_code", "SOURCE_EMPTY"))
	var declaration: Dictionary
	if prior.is_empty():
		if int(bound.observation_v3.semantic_step) != int(source.initializer.epoch_start_global_step) + 1:
			return _refuse(packet, "ENTRY_PREFIX_MISSING")
		# Fresh declaration only. Select the prospective profile before the
		# first native call; no observed declaration or threshold is replaced.
		declaration = Prior.declaration_v1(sdk, context, attempt_id, 240, bound)
		if declaration.is_empty(): return _refuse(packet, "ENTRY_DECLARATION_REFUSED")
		declaration.initialization.threshold_profile_id = PROFILE
	else:
		if (prior.get("schema_version") != STATE or not (prior.get("declaration") is Dictionary)
			or not (prior.get("selector_memory") is Dictionary)
			or not (prior.selector_memory.get("original_memory") is Dictionary)
			or not (prior.selector_memory.original_memory.get("passive_memory") is Dictionary)):
			return _refuse(packet, "ENTRY_PRIOR_SHAPE")
		declaration = prior.declaration
	if (declaration.get("attempt_id") != Prior.canonical_attempt_id_v1(attempt_id)
		or declaration.get("maximum_descent_steps") != 240
		or declaration.get("first_semantic_step") != int(source.initializer.epoch_start_global_step) + 1
		or declaration.get("initialization", {}).get("threshold_profile_id") != PROFILE):
		return _refuse(packet, "ENTRY_DECLARATION_CROSSED")
	var selector: Variant = prior.get("selector_memory")
	var passive_request := {"schema_version": Prior.Runtime.PASSIVE_ENTRY_REQUEST_V1_SCHEMA,
		"declaration": declaration, "prior": selector.original_memory.passive_memory if selector is Dictionary else null,
		"observation": bound.observation_v3, "native_global_energy": source.global_totals,
		"energy_increment": source.energy_increment}
	var original := {"schema_version": "sporespore_r10k_recovery_entry_request_v1",
		"passive_request": passive_request, "prior": selector.original_memory if selector is Dictionary else null}
	var request := {"schema_version": "sporespore_r10q_upright_entry_control_request_v1",
		"entry": {"schema_version": "sporespore_r10q_upright_entry_request_v1", "original_request": original, "prior": selector},
		"collection": Original.collection_v1(context, bound, false, "")}
	packet["call"] = call_v1(sdk, "recovery_r10q_upright_entry_control_v1_json", request)
	if packet.call.get("ok") != true: return _refuse(packet, "ENTRY_NATIVE_REFUSED")
	var receipt: Dictionary = packet.call.value
	if (receipt.get("schema_version") != "sporespore_r10q_upright_entry_control_receipt_v1"
		or not (receipt.get("original_control") is Dictionary)
		or receipt.get("entry", {}).get("original_entry") != receipt.original_control.get("entry")):
		return _refuse(packet, "ENTRY_RECEIPT_SCHEMA_OR_ORIGINAL")
	packet["native_receipt"] = receipt
	packet["original_control_receipt"] = receipt.original_control
	packet["original_passive_receipt"] = receipt.original_control.entry.original_passive_receipt
	packet["entry_state"] = {"schema_version": STATE, "declaration": declaration.duplicate(true),
		"selector_memory": receipt.entry.memory.duplicate(true)}
	packet["entry_kind"] = receipt.entry.memory.route
	packet["ok"] = true
	return packet

static func step_v1(sdk: Object, context: Dictionary, attempt_id: String, bound: Dictionary,
	declaration: Dictionary, memory: Dictionary) -> Dictionary:
	var packet := _packet("upright_step", attempt_id, bound)
	var source := source_v1(sdk, context, attempt_id, bound)
	if source.get("ok") != true: return _refuse(packet, source.get("failure_code", "SOURCE_EMPTY"))
	if (declaration.get("schema_version") != "sporespore_upright_recovery_declaration_v1"
		or declaration.get("task_id") != Source.TASK or declaration.get("semantics_id") != Source.SEMANTICS
		or memory.get("schema_version") != "sporespore_upright_recovery_memory_v1"
		or memory.get("phase") not in Source.PHASES
		or declaration.get("entry_request", {}).get("original_request", {}).get("passive_request", {}).get("declaration", {}).get("attempt_id") != Prior.canonical_attempt_id_v1(attempt_id)):
		return _refuse(packet, "UPRIGHT_STATE_CROSSED")
	var request := step_request_v1(context, bound, declaration, memory, source)
	packet["call"] = call_v1(sdk, "recovery_upright_step_control_v1_json", request)
	if packet.call.get("ok") != true: return _refuse(packet, "UPRIGHT_NATIVE_REFUSED")
	if packet.call.value.get("schema_version") != "sporespore_upright_recovery_step_control_receipt_v1": return _refuse(packet, "UPRIGHT_RECEIPT_SCHEMA")
	packet["native_receipt"] = packet.call.value
	packet["ok"] = true
	return packet

## Pure request construction after source validation. The native call still
## independently validates source identity, clocks, memory, task and energy.
static func step_request_v1(context: Dictionary, bound: Dictionary, declaration: Dictionary,
	memory: Dictionary, source: Dictionary) -> Dictionary:
	# Preserve the exact descriptor carried through native entry. A canonical
	# hash can hide a one-ULP difference in a reconstructed geometry constant.
	var original: Variant = declaration
	for key in ["entry_request", "original_request", "passive_request", "declaration", "initialization", "descriptor"]:
		original = original.get(key, {}) if original is Dictionary else {}
	return {"schema_version": "sporespore_upright_recovery_step_control_request_v1",
		"collection": collection_v1(context, bound, true, memory.phase, original if original is Dictionary else {}),
		"step": {"schema_version": "sporespore_upright_recovery_step_request_v1", "declaration": declaration,
			"memory": memory, "observation": bound.observation_v3,
			"energy_increment": source.energy_increment, "native_global_energy": source.global_totals}}

static func source_v1(sdk: Object, context: Dictionary, attempt_id: String, bound: Dictionary) -> Dictionary:
	return Original.source_v1(sdk, context, attempt_id, bound)

static func collection_v1(context: Dictionary, bound: Dictionary, upright: bool, phase: String, exact_descriptor: Dictionary = {}) -> Dictionary:
	var request := Original.collection_v1(context, bound, upright, phase, exact_descriptor)
	# A new request from a source already measured under this task. The native
	# interface independently rejects mismatched observation/source identities.
	if upright:
		request.task_id = Source.TASK
		request.semantics_id = Source.SEMANTICS
	return request

static func call_v1(sdk: Object, method: String, request: Dictionary) -> Dictionary:
	return Original.call_v1(sdk, method, request)

static func _packet(kind: String, attempt_id: String, bound: Dictionary) -> Dictionary:
	return {"schema_version": "sporespore_r10q_upright_recovery_stage_v1", "stage_kind": kind,
		"ledger_scope": {"subsystem": "recovery", "engine_scope": "godot_jolt", "authority_mode": "development_source_bridge", "question_class": "development"},
		"ok": false, "failure_code": "", "source_attempt_id": attempt_id, "bound_observations": bound.duplicate(true),
		"call": null, "native_receipt": null, "world_build_count": 0, "solver_step_count": 0,
		"native_readback_count": 0, "controller_command_applied": false,
		"source_observation_rewritten": false, "physical_acceptance_authority": false, "release_authority": false}

static func _refuse(packet: Dictionary, reason: String) -> Dictionary:
	packet.failure_code = "R10Q_UPRIGHT_STAGE_" + reason
	return packet
