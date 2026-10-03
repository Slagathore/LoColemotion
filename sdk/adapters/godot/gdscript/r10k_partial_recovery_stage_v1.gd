extends RefCounted
# gdlint: disable=max-line-length

## Production source bridge. Retains supplied source and every native call.
## It never creates a world, reads the solver, applies a motor or resets energy.
const Prior := preload("res://sdk/adapters/godot/gdscript/development_passive_entry_stage_v1.gd")
const Source := preload("res://sdk/adapters/godot/gdscript/r10k_partial_task_source_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const Bytes := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_transport_v1.gd")
const PROFILE := "sporespore_r10k_exact_s169_prone_thresholds_v1"
const STATE := "sporespore_r10k_passive_entry_bridge_state_v1"

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
			or not (prior.get("selector_memory") is Dictionary)):
			return _refuse(packet, "ENTRY_PRIOR_SHAPE")
		declaration = prior.declaration
	if (declaration.get("attempt_id") != Prior.canonical_attempt_id_v1(attempt_id)
		or declaration.get("maximum_descent_steps") != 240
		or declaration.get("first_semantic_step") != int(source.initializer.epoch_start_global_step) + 1
		or declaration.get("initialization", {}).get("threshold_profile_id") != PROFILE):
		return _refuse(packet, "ENTRY_DECLARATION_CROSSED")
	var selector: Variant = prior.get("selector_memory")
	var passive_request := {"schema_version": Prior.Runtime.PASSIVE_ENTRY_REQUEST_V1_SCHEMA,
		"declaration": declaration, "prior": selector.passive_memory if selector is Dictionary else null,
		"observation": bound.observation_v3, "native_global_energy": source.global_totals,
		"energy_increment": source.energy_increment}
	var request := {"schema_version": "sporespore_r10k_entry_control_request_v1",
		"entry": {"schema_version": "sporespore_r10k_recovery_entry_request_v1", "passive_request": passive_request, "prior": selector},
		"collection": collection_v1(context, bound, false, "")}
	packet["call"] = call_v1(sdk, "recovery_r10k_entry_control_v1_json", request)
	if packet.call.get("ok") != true: return _refuse(packet, "ENTRY_NATIVE_REFUSED")
	var receipt: Dictionary = packet.call.value
	if receipt.get("schema_version") != "sporespore_r10k_entry_control_receipt_v1": return _refuse(packet, "ENTRY_RECEIPT_SCHEMA")
	packet["native_receipt"] = receipt
	packet["original_passive_receipt"] = receipt.entry.original_passive_receipt
	packet["entry_state"] = {"schema_version": STATE, "declaration": declaration.duplicate(true),
		"selector_memory": receipt.entry.memory.duplicate(true)}
	packet["entry_kind"] = receipt.entry.memory.route
	packet["ok"] = true
	return packet

static func step_v1(sdk: Object, context: Dictionary, attempt_id: String, bound: Dictionary,
	declaration: Dictionary, memory: Dictionary) -> Dictionary:
	var packet := _packet("partial_step", attempt_id, bound)
	var source := source_v1(sdk, context, attempt_id, bound)
	if source.get("ok") != true: return _refuse(packet, source.get("failure_code", "SOURCE_EMPTY"))
	if (declaration.get("schema_version") != "sporespore_partial_fall_declaration_v1"
		or declaration.get("task_id") != Source.TASK or declaration.get("semantics_id") != Source.SEMANTICS
		or memory.get("schema_version") != "sporespore_partial_fall_memory_v1"
		or memory.get("phase") not in Source.PHASES
		or declaration.get("entry_request", {}).get("passive_request", {}).get("declaration", {}).get("attempt_id") != Prior.canonical_attempt_id_v1(attempt_id)):
		return _refuse(packet, "PARTIAL_STATE_CROSSED")
	var request := step_request_v1(context, bound, declaration, memory, source)
	packet["call"] = call_v1(sdk, "recovery_partial_fall_step_control_v1_json", request)
	if packet.call.get("ok") != true: return _refuse(packet, "PARTIAL_NATIVE_REFUSED")
	if packet.call.value.get("schema_version") != "sporespore_partial_fall_step_control_receipt_v1": return _refuse(packet, "PARTIAL_RECEIPT_SCHEMA")
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
	for key in ["entry_request", "passive_request", "declaration", "initialization", "descriptor"]:
		original = original.get(key, {}) if original is Dictionary else {}
	return {"schema_version": "sporespore_partial_fall_step_control_request_v1",
		"collection": collection_v1(context, bound, true, memory.phase, original if original is Dictionary else {}),
		"step": {"schema_version": "sporespore_partial_fall_step_request_v1", "declaration": declaration,
			"memory": memory, "observation": bound.observation_v3,
			"energy_increment": source.energy_increment, "native_global_energy": source.global_totals}}

static func source_v1(sdk: Object, context: Dictionary, attempt_id: String, bound: Dictionary) -> Dictionary:
	if sdk == null: return {"ok": false, "failure_code": "RUNTIME_MISSING"}
	for key in ["observation_v2", "observation_v3", "source_binding", "energy_source_receipt", "source_component_receipts"]:
		if not (bound.get(key) is Dictionary): return {"ok": false, "failure_code": "BOUND_SOURCE_MISSING:" + key}
	for key in ["morphology_context", "capability", "runtime_binding"]:
		if not (context.get(key) is Dictionary): return {"ok": false, "failure_code": "CONTEXT_MISSING:" + key}
	if not Prior.representations_agree_v1(bound): return {"ok": false, "failure_code": "OBSERVATION_REPRESENTATIONS_CROSSED"}
	var source: Dictionary = bound.energy_source_receipt
	var components: Dictionary = bound.source_component_receipts
	if not Prior.Epoch.source_components_complete_v1(sdk, source, components): return {"ok": false, "failure_code": "EPOCH_COMPONENTS_INVALID"}
	var initializer: Dictionary = components.epoch_initializer
	if not Prior.Initializer.initializer_valid_v1(sdk, initializer) or initializer.get("attempt_id") != attempt_id:
		return {"ok": false, "failure_code": "EPOCH_ATTEMPT_INVALID"}
	var raw: Dictionary = components.rotation_aware_energy_source_receipt
	var native_components: Dictionary = components.rotation_aware_source_component_receipts
	if not (native_components.get("complete_energy_inputs_receipt") is Dictionary): return {"ok": false, "failure_code": "NATIVE_ENERGY_INPUTS_MISSING"}
	var inputs: Dictionary = native_components.complete_energy_inputs_receipt
	# Same commissioned post-kick external/dissipation profile as passive entry.
	# Actuator, constraint and staging terms remain signed source measurements.
	if (raw.get("cumulative_signed_external_work_j") != 0.0 or raw.get("cumulative_passive_dissipation_j") != 0.0
		or inputs.get("external_intervention_event_count") != 0 or inputs.get("step_signed_external_work_j") != 0.0
		or inputs.get("step_passive_dissipation_j") != 0.0 or inputs.get("passive_dissipation_partition_complete") != true):
		return {"ok": false, "failure_code": "ZERO_EXTERNAL_DISSIPATION_PROFILE_REQUIRED"}
	return {"ok": true, "initializer": initializer,
		"global_totals": Prior.global_totals_v1(raw, components.rotation_aware_energy_source_receipt_sha256),
		"energy_increment": {"sequence_index": int(source.epoch_local_step), "semantic_step": int(bound.observation_v3.semantic_step),
			"applied_actuator_work_j": float(raw.step_actuator_work_j),
			"signed_external_work_j": float(inputs.step_signed_external_work_j),
			"signed_constraint_exchange_j": float(raw.step_signed_constraint_exchange_j),
			"signed_discrete_staging_exchange_j": float(source.step_signed_discrete_staging_exchange_j),
			"passive_dissipation_j": float(inputs.step_passive_dissipation_j), "source_measurement": true}}

static func collection_v1(context: Dictionary, bound: Dictionary, partial: bool, phase: String, exact_descriptor: Dictionary = {}) -> Dictionary:
	var result := {"schema_version": "sporespore_recovery_native_collection_request_v3" if partial else "sporespore_recovery_passive_native_collection_request_v1",
		"task_id": Source.TASK if partial else Source.CANONICAL_TASK,
		"semantics_id": Source.SEMANTICS if partial else Source.CANONICAL_SEMANTICS,
		"actuator_profile_id": Prior.Route.ACTUATOR_PROFILE_ID, "descriptor": exact_descriptor if not exact_descriptor.is_empty() else Prior.Route.exact_base_descriptor_v1(),
		"morphology_context": context.morphology_context, "adapter_capability": context.capability,
		"runtime_binding": context.runtime_binding, "arm_kind": "candidate_command",
		"observation": bound.observation_v2, "observation_source_binding": bound.source_binding}
	if partial: result["phase"] = phase
	return result

static func call_v1(sdk: Object, method: String, request: Dictionary) -> Dictionary:
	var call := {"ok": false, "method": method, "request": Bytes.bytes_v1(Transport.stringify(request)),
		"response": null, "compiled_call_count": 0, "value": null}
	if sdk == null or not sdk.has_method(method) or not sdk.has_method("decode_exact_json_v1"): return call
	var raw: String = sdk.call(method, call.request.utf8_text)
	call.compiled_call_count = 1
	call.response = Bytes.bytes_v1(raw)
	var decoded: Variant = sdk.decode_exact_json_v1(raw)
	if not (decoded is Dictionary) or decoded.get("ok") != true or not (decoded.get("value") is Dictionary): return call
	call.value = decoded.value
	call.ok = true
	return call

static func _packet(kind: String, attempt_id: String, bound: Dictionary) -> Dictionary:
	return {"schema_version": "sporespore_r10k_partial_recovery_stage_v1", "stage_kind": kind,
		"ledger_scope": {"subsystem": "recovery", "engine_scope": "godot_jolt", "authority_mode": "development_source_bridge", "question_class": "development"},
		"ok": false, "failure_code": "", "source_attempt_id": attempt_id, "bound_observations": bound.duplicate(true),
		"call": null, "native_receipt": null, "world_build_count": 0, "solver_step_count": 0,
		"native_readback_count": 0, "controller_command_applied": false,
		"source_observation_rewritten": false, "physical_acceptance_authority": false, "release_authority": false}

static func _refuse(packet: Dictionary, reason: String) -> Dictionary:
	packet.failure_code = "R10K_PARTIAL_STAGE_" + reason
	return packet
