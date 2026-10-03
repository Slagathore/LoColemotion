extends RefCounted
# gdlint: disable=max-line-length

## Production-source bridge only: no world, native read, motor command or step.
## The worker must retain this packet even when either compiled call refuses.
const Route := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const Epoch := preload("res://sdk/adapters/godot/gdscript/recovery_epoch_discrete_staging_route_v1.gd")
const Initializer := preload("res://sdk/adapters/godot/gdscript/recovery_epoch_energy_initializer_v1.gd")
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const Bytes := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_transport_v1.gd")
const SCHEMA := "sporespore_development_passive_entry_stage_v1"


static func advance_v1(
	sdk: Object, context: Dictionary, attempt_id: String, maximum_descent_steps: int,
	bound: Dictionary, prior: Dictionary = {},
) -> Dictionary:
	var packet := {
		"schema_version": SCHEMA, "ok": false, "failure_code": "",
		"ledger_scope": {"subsystem": "recovery", "engine_scope": "godot_jolt",
			"authority_mode": "development_source_bridge", "question_class": "development"},
		"source_attempt_id": attempt_id,
		"bound_observations": bound.duplicate(true), "collection_call": null,
		"entry_call": null, "entry_state": null, "entry_receipt": null,
		"model_construction_count": 0, "world_build_count": 0,
		"native_readback_count": 0, "solver_step_count": 0,
		"controller_command_emitted": false, "physics_state_modified": false,
		"physical_acceptance_authority": false, "release_authority": false,
	}
	for key in ["observation_v2", "observation_v3", "source_binding",
		"energy_source_receipt", "source_component_receipts"]:
		if not (bound.get(key) is Dictionary):
			return _refuse(packet, "PASSIVE_ENTRY_BOUND_SOURCE_MISSING:" + key)
	for key in ["morphology_context", "capability", "runtime_binding"]:
		if not (context.get(key) is Dictionary):
			return _refuse(packet, "PASSIVE_ENTRY_CONTEXT_MISSING:" + key)
	if not representations_agree_v1(bound):
		return _refuse(packet, "PASSIVE_ENTRY_OBSERVATION_REPRESENTATIONS_CROSSED")
	var source: Dictionary = bound["energy_source_receipt"]
	var components: Dictionary = bound["source_component_receipts"]
	if not Epoch.source_components_complete_v1(sdk, source, components):
		return _refuse(packet, "PASSIVE_ENTRY_EPOCH_COMPONENTS_INVALID")
	var initializer: Dictionary = components["epoch_initializer"]
	if not Initializer.initializer_valid_v1(sdk, initializer):
		return _refuse(packet, "PASSIVE_ENTRY_EPOCH_INITIALIZER_INVALID")
	if initializer.get("attempt_id") != attempt_id:
		return _refuse(packet, "PASSIVE_ENTRY_ATTEMPT_CROSSED")
	var observation: Dictionary = bound["observation_v3"]
	var raw: Dictionary = components["rotation_aware_energy_source_receipt"]
	var native_components: Dictionary = components["rotation_aware_source_component_receipts"]
	if not (native_components.get("complete_energy_inputs_receipt") is Dictionary):
		return _refuse(packet, "PASSIVE_ENTRY_NATIVE_ENERGY_INPUTS_MISSING")
	var native_inputs: Dictionary = native_components["complete_energy_inputs_receipt"]
	# This exact commissioned profile has zero external work/dissipation in
	# passive descent. Refuse an unexercised profile; never infer missing work
	# from a residual or subtract two local totals to manufacture an increment.
	if (raw.get("cumulative_signed_external_work_j") != 0.0
		or raw.get("cumulative_passive_dissipation_j") != 0.0
		or native_inputs.get("external_intervention_event_count") != 0
		or native_inputs.get("step_signed_external_work_j") != 0.0
		or native_inputs.get("step_passive_dissipation_j") != 0.0
		or native_inputs.get("passive_dissipation_partition_complete") != true):
		return _refuse(packet, "PASSIVE_ENTRY_ZERO_EXTERNAL_DISSIPATION_PROFILE_REQUIRED")
	var collection_request := {
		"schema_version": "sporespore_recovery_passive_native_collection_request_v1",
		"task_id": Route.TASK_ID, "semantics_id": Route.SEMANTICS_ID,
		"actuator_profile_id": Route.ACTUATOR_PROFILE_ID,
		"descriptor": Route.exact_base_descriptor_v1(),
		"morphology_context": context["morphology_context"],
		"adapter_capability": context["capability"], "runtime_binding": context["runtime_binding"],
		"arm_kind": "candidate_command", "observation": bound["observation_v2"],
		"observation_source_binding": bound["source_binding"],
	}
	var collected := _call_v1(sdk, "recovery_collect_passive_native_v1_json", collection_request)
	packet["collection_call"] = collected
	if not collected.get("ok", false):
		return _refuse(packet, "PASSIVE_ENTRY_NATIVE_COLLECTION_TRANSPORT_REFUSED")
	var collection: Dictionary = collected["value"]["collection"]
	if collection.get("support_status") != "supported_exact" or collection.get("supplied_native_post_step_observation_validated") != true:
		return _refuse(packet, "PASSIVE_ENTRY_NATIVE_COLLECTION_REFUSED")
	var declaration: Dictionary
	if prior.is_empty():
		if int(observation["semantic_step"]) != int(initializer["epoch_start_global_step"]) + 1:
			return _refuse(packet, "PASSIVE_ENTRY_MISSING_EPOCH_PREFIX")
		declaration = declaration_v1(sdk, context, attempt_id, maximum_descent_steps, bound)
		if declaration.is_empty():
			return _refuse(packet, "PASSIVE_ENTRY_DECLARATION_REFUSED")
	else:
		if not (prior.get("declaration") is Dictionary) or not (prior.get("memory") is Dictionary):
			return _refuse(packet, "PASSIVE_ENTRY_PRIOR_MISSING")
		declaration = prior["declaration"]
		if (declaration.get("attempt_id") != canonical_attempt_id_v1(attempt_id)
			or declaration.get("maximum_descent_steps") != maximum_descent_steps
			or int(declaration.get("first_semantic_step", -1)) != int(initializer["epoch_start_global_step"]) + 1):
			return _refuse(packet, "PASSIVE_ENTRY_DECLARATION_CROSSED")
	var request := {
		"schema_version": Runtime.PASSIVE_ENTRY_REQUEST_V1_SCHEMA,
		"declaration": declaration, "prior": prior.get("memory"), "observation": observation,
		"native_global_energy": global_totals_v1(raw, String(components["rotation_aware_energy_source_receipt_sha256"])),
		"energy_increment": {
			"sequence_index": int(source["epoch_local_step"]),
			"semantic_step": int(observation["semantic_step"]),
			"applied_actuator_work_j": float(raw["step_actuator_work_j"]),
			"signed_external_work_j": float(native_inputs["step_signed_external_work_j"]),
			"signed_constraint_exchange_j": float(raw["step_signed_constraint_exchange_j"]),
			"signed_discrete_staging_exchange_j": float(source["step_signed_discrete_staging_exchange_j"]),
			"passive_dissipation_j": float(native_inputs["step_passive_dissipation_j"]), "source_measurement": true,
		},
	}
	var stepped := _call_v1(sdk, "recovery_passive_entry_step_v1_json", request)
	packet["entry_call"] = stepped
	if not stepped.get("ok", false):
		return _refuse(packet, "PASSIVE_ENTRY_COMPILED_STEP_REFUSED")
	var receipt: Dictionary = stepped["value"]
	packet["entry_receipt"] = receipt
	packet["entry_state"] = {"declaration": declaration.duplicate(true), "memory": receipt["memory"].duplicate(true)}
	packet["ok"] = true
	return packet


static func representations_agree_v1(bound: Dictionary) -> bool:
	var first: Dictionary = bound["observation_v2"].duplicate(true)
	var second: Dictionary = bound["observation_v3"].duplicate(true)
	if (first.get("schema_version") != "sporespore_recovery_observation_v2"
		or second.get("schema_version") != "sporespore_recovery_observation_v3"
		or not (first.get("energy_balance") is Dictionary)
		or not (second.get("energy_balance") is Dictionary)):
		return false
	var energy2: Dictionary = first["energy_balance"].duplicate(true)
	var energy3: Dictionary = second["energy_balance"].duplicate(true)
	if (energy3.get("schema_version") != "sporespore_recovery_energy_balance_ledger_v3"
		or energy3.get("equation_id") != "current_minus_initial_minus_actuator_minus_external_minus_constraint_minus_discrete_staging_plus_passive_v3"
		or energy3.get("component_partition_id") != "sporespore_disjoint_actuator_external_constraint_discrete_staging_passive_energy_partition_v3"
		or energy3.get("cumulative_signed_discrete_staging_exchange_j") != bound["energy_source_receipt"].get("cumulative_signed_discrete_staging_exchange_j")):
		return false
	for observation in [first, second]:
		observation.erase("schema_version")
		observation.erase("energy_balance")
	for energy in [energy2, energy3]:
		energy.erase("schema_version")
		energy.erase("equation_id")
		energy.erase("component_partition_id")
	energy3.erase("cumulative_signed_discrete_staging_exchange_j")
	return (Transport.stringify(first) == Transport.stringify(second)
		and Transport.stringify(energy2) == Transport.stringify(energy3))


static func declaration_v1(sdk: Object, context: Dictionary, attempt_id: String, maximum_descent_steps: int, bound: Dictionary) -> Dictionary:
	var initializer: Dictionary = bound["source_component_receipts"]["epoch_initializer"]
	var observation: Dictionary = bound["observation_v3"]
	var authority := Route.commissioned_discrete_staging_complete_energy_partition_authority_v1(sdk, context, bound)
	if authority.is_empty():
		return {}
	# A declared boundary projection from the original kick initializer, not a
	# modification of any measured observation or of an existing canonical memory.
	var boundary_energy: Dictionary = observation["energy_balance"].duplicate(true)
	boundary_energy["source_values_sha256"] = initializer["payload_sha256"]
	boundary_energy["current_mechanical_energy_j"] = initializer["initial_mechanical_energy_j"]
	for field in ["cumulative_applied_actuator_work_j", "cumulative_signed_external_work_j",
		"cumulative_signed_constraint_exchange_j", "cumulative_signed_discrete_staging_exchange_j",
		"cumulative_passive_dissipation_j"]:
		boundary_energy[field] = 0.0
	return {
		"schema_version": "sporespore_recovery_passive_entry_declaration_v1",
		"attempt_id": canonical_attempt_id_v1(attempt_id), "maximum_descent_steps": maximum_descent_steps,
		"first_semantic_step": int(initializer["epoch_start_global_step"]) + 1,
		"first_host_step_before": int(observation["engine_step_identity"]["host_step_before"]),
		"initialization": {
			"schema_version": Runtime.INITIALIZE_REQUEST_V2_SCHEMA,
			"task_id": Route.TASK_ID, "semantics_id": Route.SEMANTICS_ID,
			"actuator_profile_id": Route.ACTUATOR_PROFILE_ID,
			"threshold_profile_id": Route.THRESHOLD_PROFILE_ID,
			"descriptor": Route.exact_base_descriptor_v1(),
			"morphology_context": context["morphology_context"],
			"adapter_capability": context["capability"], "arm_kind": "candidate_command",
		},
		"energy_at_boundary": boundary_energy, "energy_boundary_sequence_index": 0,
		"energy_partition_authority": authority,
		"native_global_energy_at_boundary": {
			"source_values_sha256": initializer["rotation_aware_energy_source_receipt_sha256"],
			"cumulative_applied_actuator_work_j": initializer["global_cumulative_applied_actuator_work_at_epoch_start_j"],
			"cumulative_signed_external_work_j": initializer["global_cumulative_signed_external_work_at_epoch_start_j"],
			"cumulative_signed_constraint_exchange_j": initializer["global_cumulative_signed_constraint_exchange_at_epoch_start_j"],
			"cumulative_passive_dissipation_j": initializer["global_cumulative_passive_dissipation_at_epoch_start_j"],
		},
	}


static func canonical_attempt_id_v1(source_attempt_id: String) -> String:
	# Lossless UTF-8 encoding into the canonical lowercase/digit/underscore
	# alphabet. The original worker identity remains bound to the initializer
	# and retained in the packet; no observed identity is changed or reused.
	return "passive_entry_" + source_attempt_id.to_utf8_buffer().hex_encode()


static func global_totals_v1(raw: Dictionary, source_digest: String) -> Dictionary:
	var totals := {"source_values_sha256": source_digest}
	for field in ["cumulative_applied_actuator_work_j", "cumulative_signed_external_work_j",
		"cumulative_signed_constraint_exchange_j", "cumulative_passive_dissipation_j"]:
		totals[field] = raw[field]
	return totals


static func _call_v1(sdk: Object, method: String, request: Dictionary) -> Dictionary:
	var call := {"ok": false, "method": method, "request": Bytes.bytes_v1(Transport.stringify(request)),
		"response": null, "compiled_call_count": 0, "value": null}
	if sdk == null or not sdk.has_method(method) or not sdk.has_method("decode_passive_recovery_response_v1"):
		call["failure_code"] = "PASSIVE_ENTRY_RUNTIME_UNAVAILABLE"
		return call
	var raw: String = sdk.call(method, call["request"]["utf8_text"])
	call["compiled_call_count"] = 1
	call["response"] = Bytes.bytes_v1(raw)
	var value := Runtime._decode_passive_envelope_v1(sdk, raw)
	if value.get("ok") == false:
		call["failure_code"] = value.get("failure_code", "PASSIVE_ENTRY_RESPONSE_INVALID")
		return call
	call["value"] = value
	call["ok"] = true
	return call


static func _refuse(packet: Dictionary, reason: String) -> Dictionary:
	packet["failure_code"] = reason
	return packet
