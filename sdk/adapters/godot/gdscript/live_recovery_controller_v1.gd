extends RefCounted
## Fresh live-epoch bridge into the existing compiled entry and recovery laws.
## This module observes supplied sources and plans; it never touches a body.
const Bound := preload("res://sdk/adapters/godot/gdscript/live_recovery_observation_v1.gd")
const Epoch := Bound.Epoch
const Energy := Bound.Energy
const Route := Bound.Route
const Partial := preload("res://sdk/adapters/godot/gdscript/r10ap_partial_recovery_stage_v1.gd")
const Upright := preload("res://sdk/adapters/godot/gdscript/r10r_upright_recovery_stage_v1.gd")
const Calls := Partial.Original
const Prior := Partial.Prior
const STATE := "sporespore_live_recovery_controller_state_v1"
const PRONE_CONTROLLER := Upright.Source.RECOVERY


static func begin_v1(sdk: Object, context: Dictionary, epoch: Dictionary, energy: Dictionary, attempt_id: String) -> Dictionary:
	if (not Epoch.state_valid_v1(sdk,epoch) or not Energy.state_valid_v1(sdk,energy)
		or epoch.observed_pair_count != 0 or energy.increment_count != 0
		or energy.epoch_state_sha256 != epoch.payload_sha256 or attempt_id.is_empty()): return _failure("ORIGIN")
	var authority := Route.commissioned_discrete_staging_complete_energy_partition_authority_for_observation_v1(sdk,context,
		{"energy_balance":energy.ledger,"engine_step_identity":{"adapter_id":Route.ADAPTER_ID,
			"engine":Route.ENGINE_ID,"capability_sha256":context.capability_sha256}})
	if authority.is_empty(): return _failure("ENERGY_AUTHORITY")
	var prone_context := Route.prepare_development_candidate_context_v1(sdk,PRONE_CONTROLLER)
	if prone_context.get("ok") != true or prone_context.get("source_native_context_sha256") != Bound._sha(sdk,context): return _failure("PRONE_CONTEXT")
	var declaration := {"schema_version":"sporespore_recovery_passive_entry_declaration_v1",
		"attempt_id":Prior.canonical_attempt_id_v1(attempt_id),"maximum_descent_steps":240,
		"first_semantic_step":energy.last_global_step+1,"first_host_step_before":energy.last_global_step,
		"initialization":{"schema_version":Prior.Runtime.INITIALIZE_REQUEST_V2_SCHEMA,
			"task_id":Route.TASK_ID,"semantics_id":Route.SEMANTICS_ID,"actuator_profile_id":Route.ACTUATOR_PROFILE_ID,
			"threshold_profile_id":Partial.PROFILE,"descriptor":Route.exact_base_descriptor_v1(),
			"morphology_context":context.morphology_context,"adapter_capability":context.capability,"arm_kind":"candidate_command"},
		"energy_at_boundary":energy.ledger.duplicate(true),"energy_boundary_sequence_index":0,"energy_partition_authority":authority}
	# Absence of native_global_energy explicitly chooses the core's exact local
	# accumulation contract. Earlier uncollected walking history is not invented.
	var state := {"schema_version":STATE,"epoch_id":epoch.epoch_id,"origin_global_step":energy.last_global_step,
		"last_global_step":energy.last_global_step,"context_sha256":Bound._sha(sdk,context),"route":"entry",
		"entry_declaration":declaration,"prone_context":prone_context,"selector_memory":null,"declaration":{},"memory":{},
		"terminal":false,"terminal_phase":"","physical_acceptance_authority":false,"release_authority":false}
	return {"ok":true,"state":Epoch._seal(sdk,state)}


static func advance_v1(sdk: Object, context: Dictionary, state: Dictionary, bound: Dictionary) -> Dictionary:
	var packet := {"schema_version":"sporespore_live_recovery_controller_transition_v1","ok":false,
		"state_before_sha256":state.get("payload_sha256",""),"bound_sha256":bound.get("payload_sha256",""),
		"calls":[],"native_receipt":{},"control":null,"no_actuation_requested":true,
		"world_build_count":0,"solver_step_count":0,"physics_state_modified":false,
		"physical_acceptance_authority":false,"release_authority":false}
	if not state_valid_v1(sdk,state) or state.terminal or state.context_sha256 != Bound._sha(sdk,context): return _refuse(packet,"STATE")
	if not Bound.valid_v1(sdk,context,bound): return _refuse(packet,"BOUND")
	if (bound.observation_v3.semantic_step != state.last_global_step+1
		or bound.source_trace.epoch_id != state.epoch_id
		or bound.energy_increment.sequence_index != bound.observation_v3.semantic_step-state.origin_global_step): return _refuse(packet,"CLOCK")
	var next := state.duplicate(true)
	next.last_global_step = bound.observation_v3.semantic_step
	var result: Dictionary
	if state.route == "entry": result = _entry(sdk,context,state,bound,packet,next)
	elif state.route in ["partial","upright"]: result = _specialized(sdk,context,state,bound,packet,next)
	else: result = _prone(sdk,context,state,bound,packet,next)
	if result.get("ok") != true: return result
	packet.state_after = Epoch._seal(sdk,next)
	packet.ok = true
	packet.no_actuation_requested = packet.control == null
	return Epoch._seal(sdk,packet)


static func _entry(sdk: Object, context: Dictionary, state: Dictionary, bound: Dictionary, packet: Dictionary, next: Dictionary) -> Dictionary:
	var selector: Variant = state.selector_memory
	var passive := {"schema_version":Prior.Runtime.PASSIVE_ENTRY_REQUEST_V1_SCHEMA,"declaration":state.entry_declaration,
		"prior":selector.original_memory.passive_memory if selector is Dictionary else null,
		"observation":bound.observation_v3,"energy_increment":bound.energy_increment}
	var original := {"schema_version":"sporespore_r10k_recovery_entry_request_v1","passive_request":passive,
		"prior":selector.original_memory if selector is Dictionary else null}
	var call := _call(sdk,packet,"recovery_r10ap_partial_entry_control_v1_json",{
		"schema_version":"sporespore_r10ap_partial_progressive_headroom_entry_control_request_v1",
		"entry":{"schema_version":"sporespore_r10q_upright_entry_request_v1","original_request":original,"prior":selector},
		"collection":Partial.collection_v1(context,bound,false,"")})
	if call.get("ok") != true: return _refuse(packet,"ENTRY_CALL")
	var value: Dictionary = call.value
	if value.get("schema_version") != "sporespore_r10ap_partial_progressive_headroom_entry_control_receipt_v1" or value.get("control_composition_id") != Partial.Source.COMPOSITION: return _refuse(packet,"ENTRY_RECEIPT")
	var retained: Dictionary = value.original_entry_control
	var entry: Dictionary = retained.original_control.entry
	if retained.entry.original_entry != entry: return _refuse(packet,"ENTRY_SOURCE")
	next.selector_memory = retained.entry.memory
	var kind: String = next.selector_memory.route
	packet.native_receipt = value
	if kind == "partial":
		next.route = kind; next.declaration = entry.partial_declaration; next.memory = entry.partial_memory
		packet.control = value.initial_partial_control
	elif kind == "upright":
		next.route = kind; next.declaration = retained.entry.upright_declaration; next.memory = retained.entry.upright_memory
		packet.native_receipt = retained; packet.control = retained.initial_upright_control
	elif kind == "prone":
		next.route = kind; next.memory = entry.original_passive_receipt.canonical_memory
		# Canonical entry is followed by one real disabled-motor interval, just
		# as on the existing route. Its first control comes from the next step.
	else:
		var status: String = entry.original_passive_receipt.memory.status
		if status == "descent_timeout": next.terminal = true; next.terminal_phase = "failed"
		elif status != "waiting_for_prone": return _refuse(packet,"ENTRY_STATUS:"+status)
	return {"ok":true}


static func _specialized(sdk: Object, context: Dictionary, state: Dictionary, bound: Dictionary, packet: Dictionary, next: Dictionary) -> Dictionary:
	var source := {"energy_increment":bound.energy_increment,"global_totals":null}
	var request: Dictionary = (Partial.step_request_v1(context,bound,state.declaration,state.memory,source)
		if state.route == "partial" else Upright.step_request_v1(context,bound,state.declaration,state.memory,source))
	request.step.erase("native_global_energy")
	var method := "recovery_r10ap_partial_step_control_v1_json" if state.route == "partial" else "recovery_r10r_upright_step_control_v1_json"
	var call := _call(sdk,packet,method,request)
	if call.get("ok") != true: return _refuse(packet,"RECOVERY_CALL")
	var value: Dictionary = call.value
	var schema := "sporespore_r10ap_partial_progressive_headroom_step_control_receipt_v1" if state.route == "partial" else "sporespore_r10r_upright_direct_rise_step_control_receipt_v1"
	var composition: String = Partial.Source.COMPOSITION if state.route == "partial" else Upright.Source.COMPOSITION
	if value.get("schema_version") != schema or value.get("control_composition_id") != composition: return _refuse(packet,"RECOVERY_RECEIPT")
	next.memory = value.step.memory
	packet.native_receipt = value
	next.terminal_phase = next.memory.phase if next.memory.phase in ["complete","failed","refused"] else ""
	next.terminal = not next.terminal_phase.is_empty()
	packet.control = value.get("next_control")
	if next.terminal and packet.control != null: return _refuse(packet,"TERMINAL_CONTROL")
	if not next.terminal and not (packet.control is Dictionary): return _refuse(packet,"CONTROL_MISSING")
	return {"ok":true}


static func _prone(sdk: Object, native_context: Dictionary, state: Dictionary, bound: Dictionary, packet: Dictionary, next: Dictionary) -> Dictionary:
	var context: Dictionary = state.prone_context
	if context.get("source_native_context_sha256") != Bound._sha(sdk,native_context) or not Route.development_candidate_context_binding_exact_v1(sdk,context,PRONE_CONTROLLER): return _refuse(packet,"PRONE_CONTEXT")
	var collection := Route.collection_request_v1(context,bound,"candidate_command",state.memory.phase)
	var collected := _call(sdk,packet,"recovery_collect_native_v3_json",collection)
	if collected.get("ok") != true or collected.value.get("support_status") != "supported_exact": return _refuse(packet,"PRONE_COLLECTION")
	var authority := Route.commissioned_discrete_staging_complete_energy_partition_authority_v1(sdk,context,bound)
	if authority.is_empty(): return _refuse(packet,"PRONE_AUTHORITY")
	var stepped := _call(sdk,packet,"recovery_step_v5_json",{"schema_version":"sporespore_recovery_step_request_v5",
		"descriptor":state.entry_declaration.initialization.descriptor,"morphology_context":context.morphology_context,
		"adapter_capability":context.capability,"memory":state.memory,"observation":bound.observation_v3,"energy_partition_authority":authority})
	if stepped.get("ok") != true or stepped.value.get("schema_version") != "sporespore_recovery_step_receipt_v2": return _refuse(packet,"PRONE_STEP")
	var step: Dictionary = stepped.value.step
	if step.get("support_status") != "supported_exact" or step.get("refusal_reason") != null: return _refuse(packet,"PRONE_REFUSED")
	next.memory = step.memory
	packet.native_receipt = stepped.value
	next.terminal = next.memory.phase in ["complete","failed","refused"]
	next.terminal_phase = next.memory.phase if next.terminal else ""
	if next.terminal: return {"ok":true}
	var planned: Dictionary
	if next.memory.phase in ["stance_handoff","stance_dwell"]:
		planned = _call(sdk,packet,"recovery_plan_stance_control_v4_json",{"schema_version":"sporespore_recovery_stance_control_request_v4",
			"controller_id":Route.DevelopmentStanceProfile.for_recovery_v1(context.recovery_controller_id),"collection":collection,
			"handoff_or_stance_step":step,"portable_step_observation_v3":bound.observation_v3,
			"energy_partition_authority":authority,"development_progression":stepped.value.development_progression})
		if planned.get("ok") != true or not Route.stance_observation_binding_receipt_valid_v1(sdk,planned.value,collection,step,
			bound.observation_v3,authority,stepped.value.development_progression): return _refuse(packet,"STANCE_PLAN")
		packet.control = planned.value.control_receipt
	else:
		var next_collection := collection.duplicate(true); next_collection.phase = next.memory.phase
		planned = _call(sdk,packet,"recovery_plan_control_v3_json",{"schema_version":"sporespore_recovery_control_request_v3",
			"controller_id":context.recovery_controller_id,"phase_step":next.memory.phase_steps_observed,"collection":next_collection})
		if planned.get("ok") != true: return _refuse(packet,"PRONE_PLAN")
		packet.control = planned.value
	if packet.control.get("support_status") != "supported_exact" or packet.control.get("refusal_reason") != null: return _refuse(packet,"CONTROL_REFUSED")
	return {"ok":true}


static func state_valid_v1(sdk: Object, state: Dictionary) -> bool:
	return (Epoch._digest_matches(sdk,state) and state.get("schema_version") == STATE
		and state.get("route") in ["entry","prone","partial","upright"]
		and state.get("last_global_step",-1) >= state.get("origin_global_step",0)
		and state.get("origin_global_step",0) > 0 and state.get("entry_declaration") is Dictionary
		and state.get("prone_context") is Dictionary and state.prone_context.get("recovery_controller_id") == PRONE_CONTROLLER
		and state.get("memory") is Dictionary and typeof(state.get("terminal")) == TYPE_BOOL
		and state.get("physical_acceptance_authority") == false and state.get("release_authority") == false)


static func _call(sdk: Object, packet: Dictionary, method: String, request: Dictionary) -> Dictionary:
	var called := Calls.call_v1(sdk,method,request)
	packet.calls.append(called)
	return called


static func _refuse(packet: Dictionary, code: String) -> Dictionary:
	packet.failure_code = "LIVE_RECOVERY_CONTROLLER_"+code
	return packet


static func _failure(code: String) -> Dictionary:
	return _refuse({"ok":false,"calls":[],"world_build_count":0,"solver_step_count":0,
		"physics_state_modified":false,"physical_acceptance_authority":false,"release_authority":false},code)
