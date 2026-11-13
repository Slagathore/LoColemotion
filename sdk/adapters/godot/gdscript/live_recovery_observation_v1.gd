extends RefCounted
## Full current recovery observation from the live epoch's measured sources.
## The old setup collector and its cumulative counters are never advanced here.
const Energy := preload("res://sdk/adapters/godot/gdscript/live_recovery_energy_v1.gd")
const Epoch := Energy.Epoch
const World := Energy.World
const Route := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const SCHEMA := "sporespore_live_recovery_bound_observation_v1"


static func capture_v1(sdk: Object, context: Dictionary, model: Dictionary, epoch_transition: Dictionary,
	energy_transition: Dictionary, energy_sources: Dictionary, application: Dictionary) -> Dictionary:
	if not _energy_join(sdk, epoch_transition, energy_transition, energy_sources): return _failure("ENERGY_JOIN")
	var frame: Dictionary = epoch_transition.state_after.latest
	var step: int = frame.completed_boundary.boundary_sequence
	var task := World.TaskSource.select_v1(sdk, model, application, step)
	if task.get("ok") != true: return task
	var snapshots := {}
	for source in frame.ordered_body_sources:
		var body: Variant = model.body_nodes.get(source.body_id)
		if not (body is RigidBody3D) or not is_instance_valid(body) or body.get_instance_id() != source.instance_id: return _failure("BODY_INSTANCE")
		snapshots[source.body_id] = {"callback_sequence": source.callback_sequence, "source_measurement": true,
			"transform": Transform3D(Epoch._from_basis(source.orientation_basis), Epoch._from_vec(source.position_world_m)),
			"linear_velocity_world_m_s": Epoch._from_vec(source.linear_velocity_world_m_s),
			"angular_velocity_world_rad_s": Epoch._from_vec(source.angular_velocity_world_rad_s),
			"total_gravity_world_m_s2": Epoch._from_vec(source.total_gravity_world_m_s2),
			"inverse_inertia_tensor_world_kg_inv_m2": Epoch._from_basis(source.inverse_inertia_tensor_world_kg_inv_m2),
			"mass_kg": source.mass_kg, "solver_step_s": source.solver_step_s}
	var contacts := World._measure_contacts_v1(model, snapshots, step, frame.native_space_step_sequence)
	if contacts.get("ok") != true: return contacts
	var measured := World._measure_state_v1(context, model, snapshots, contacts, step, task)
	if measured.get("ok") != true: return measured
	var retained_contacts := World.retain_contact_source_receipt_v1(sdk, contacts)
	if retained_contacts.get("ok") != true: return retained_contacts
	return compose_v1(sdk, context, epoch_transition, energy_transition, energy_sources, application,
		measured, retained_contacts, task)


## Pure assembly shared by native capture and the synthetic refusal controls.
static func compose_v1(sdk: Object, context: Dictionary, epoch_transition: Dictionary,
	energy_transition: Dictionary, energy_sources: Dictionary, application: Dictionary,
	state_source: Dictionary, contact_source: Dictionary, task_source: Dictionary) -> Dictionary:
	if not _energy_join(sdk, epoch_transition, energy_transition, energy_sources): return _failure("ENERGY_JOIN")
	var frame: Dictionary = epoch_transition.state_after.latest
	var step: int = frame.completed_boundary.boundary_sequence
	if (state_source.get("ok") != true or contact_source.get("ok") != true or task_source.get("ok") != true
		or not (state_source.get("observation_base") is Dictionary)
		or not (state_source.get("direct_state_source_receipt") is Dictionary)
		or not (contact_source.get("contact_source_receipt") is Dictionary)): return _failure("STATE_OR_CONTACT_SOURCE")
	if (state_source.observation_base.get("semantic_step") != step or state_source.direct_state_source_receipt.get("semantic_step") != step
		or contact_source.contact_source_sha256 != _sha(sdk,contact_source.contact_source_receipt)): return _failure("SOURCE_CLOCK_OR_DIGEST")
	if not _source_projection_valid(sdk,context,frame,state_source,contact_source): return _failure("SOURCE_PROJECTION")
	if (application.get("ok") != true or application.get("semantic_step") != step
		or application.get("source_control_semantic_step") != step-1
		or application.get("no_actuation_requested") != energy_sources.raw.no_actuation_requested
		or application.get("adapter_side_discrete_staging_event_count") != 0): return _failure("APPLICATION_JOIN")
	var ownership := World.controller_ownership_observation_v1(sdk, application)
	if ownership.get("ok") != true: return ownership
	var components := {"schema_version": "sporespore_live_recovery_observation_sources_v1",
		"epoch_transition": epoch_transition, "energy_transition": energy_transition,
		"energy_sources": energy_sources, "application": application, "state_source": state_source,
		"contact_source": contact_source, "task_source": task_source}
	var components_sha := _sha(sdk,components)
	var trace := {"schema_version": "sporespore_live_recovery_observation_source_trace_v1",
		"global_semantic_step": step, "native_space_step_sequence": frame.native_space_step_sequence,
		"epoch_id": epoch_transition.state_after.epoch_id, "source_component_receipts_sha256": components_sha,
		"source_measurement": true, "unobserved_history_claimed": false}
	var impulses: Array = []
	for motor in energy_sources.motor_receipts:
		impulses.append({"actuator_id": motor.actuator_id, "applied_angular_impulse_nms": motor.signed_motor_impulse_nms, "host_clamped": false})
	var base: Dictionary = state_source.observation_base.duplicate(true)
	if base.get("task_id") != task_source.task_id or base.get("semantics_id") != task_source.semantics_id: return _failure("TASK_JOIN")
	base.applied_actuation = {"adapter_id": World.ADAPTER_ID, "adapter_receipt_sha256": _sha(sdk,application),
		"source_semantic_step": step, "command_id": application.command_id, "command_sha256": application.command_sha256,
		"actuator_profile_id": World.ACTUATOR_PROFILE_ID, "actuator_profile_sha256": World.ACTUATOR_PROFILE_SHA256,
		"zero_command": application.zero_command, "ordered_applied_impulses": impulses, "source_measurement": true}
	base.external_interventions = World._zero_external_interventions_v1()
	base.controller_ownership = ownership.observation
	base.engine_step_identity = {"schema_version": "sporespore_recovery_engine_step_identity_v1", "source_kind": "native_post_step",
		"adapter_id": World.ADAPTER_ID, "engine": World.ENGINE_ID, "capability_sha256": context.capability_sha256,
		"source_trace_sha256": _sha(sdk,trace), "semantic_step": step, "host_step_before": step-1, "host_step_after": step,
		"native_solver_substep_count": 1, "post_step_observation": true, "engine_identity_exposed_to_policy": false}
	var energy3: Dictionary = energy_transition.state_after.ledger.duplicate(true)
	var energy2 := energy3.duplicate(true)
	energy2.schema_version = "sporespore_recovery_energy_balance_ledger_v2"
	energy2.equation_id = "current_minus_initial_minus_actuator_minus_external_minus_constraint_plus_passive_v2"
	energy2.component_partition_id = "sporespore_disjoint_actuator_external_constraint_passive_energy_partition_v2"
	energy2.erase("cumulative_signed_discrete_staging_exchange_j")
	var second := base.duplicate(true); second.schema_version = "sporespore_recovery_observation_v2"; second.energy_balance = energy2
	var third := base.duplicate(true); third.schema_version = "sporespore_recovery_observation_v3"; third.energy_balance = energy3
	# Same qualified numeric mapping as the native epoch route; richer live
	# provenance remains explicit in this sidecar, outside the portable ABI.
	var binding := {"schema_version": "sporespore_recovery_observation_v2_source_binding_v1",
		"producer_adapter_id": World.ADAPTER_ID, "source_route_id": Epoch.Staging.ROUTE_ID,
		"mapping_profile_id": Epoch.Staging.MAPPING_PROFILE_ID, "mapping_receipt_sha256": energy_transition.payload_sha256,
		"source_component_receipts_sha256": components_sha, "observation_base_sha256": _sha(sdk,base),
		"ledger_sha256": _sha(sdk,energy2), "portable_observation_sha256": _sha(sdk,second)}
	binding.source_chain_sha256 = _sha(sdk,binding)
	return Epoch._seal(sdk, {"schema_version": SCHEMA, "ok": true, "observation_v2": second,
		"observation_v3": third, "source_binding": binding, "source_trace": trace, "source_component_receipts": components,
		"energy_increment": energy_transition.energy_increment, "world_build_count": 0, "solver_step_count": 0,
		"physics_state_modified": false, "physical_acceptance_authority": false, "release_authority": false})


static func valid_v1(sdk: Object, context: Dictionary, bound: Dictionary) -> bool:
	if not Epoch._digest_matches(sdk,bound) or bound.get("schema_version") != SCHEMA or bound.get("ok") != true: return false
	var c: Variant = bound.get("source_component_receipts")
	if not (c is Dictionary): return false
	for key in ["epoch_transition","energy_transition","energy_sources","application","state_source","contact_source","task_source"]:
		if not (c.get(key) is Dictionary): return false
	var rebuilt := compose_v1(sdk,context,c.epoch_transition,c.energy_transition,c.energy_sources,
		c.application,c.state_source,c.contact_source,c.task_source)
	return rebuilt.get("ok") == true and rebuilt == bound


static func _source_projection_valid(sdk: Object, context: Dictionary, frame: Dictionary, measured: Dictionary, contacts: Dictionary) -> bool:
	var step: int = frame.completed_boundary.boundary_sequence
	var direct: Dictionary = measured.direct_state_source_receipt
	var source: Dictionary = contacts.contact_source_receipt
	if (direct.get("source_measurement") != true or source.get("source_measurement") != true
		or source.get("semantic_step") != step or source.get("native_space_step_sequence") != frame.native_space_step_sequence
		or not (direct.get("ordered_body_states") is Array) or direct.ordered_body_states.size() != 9
		or World.retain_contact_source_receipt_v1(sdk,{"source_receipt":source}) != contacts): return false
	for index in range(9):
		var retained: Dictionary = direct.ordered_body_states[index]
		var raw: Dictionary = frame.ordered_body_sources[index]
		var quaternion := World.project_quaternion_to_unit_scalar_v1(Epoch._from_basis(raw.orientation_basis).get_rotation_quaternion())
		if (retained.get("body_id") != raw.body_id or retained.get("callback_sequence") != step
			or retained.get("mass_kg") != raw.mass_kg or quaternion.get("ok") != true
			or retained.get("orientation_xyzw") != quaternion.orientation_xyzw): return false
		for key in ["position_world_m","linear_velocity_world_m_s","angular_velocity_world_rad_s"]:
			if Epoch._from_vec(retained.get(key)) != Epoch._from_vec(raw[key]): return false
	var torso: Dictionary = direct.ordered_body_states[0]
	var base: Dictionary = measured.observation_base
	var state: Variant = base.get("state")
	if not (state is Dictionary) or state.get("semantic_step") != step or state.get("adapter_capability_sha256") != context.capability_sha256: return false
	return (state.get("base_pose_world") == {"position_m":torso.position_world_m,"orientation_xyzw":torso.orientation_xyzw}
		and state.get("base_twist_world") == {"linear_velocity_m_s":torso.linear_velocity_world_m_s,"angular_velocity_rad_s":torso.angular_velocity_world_rad_s}
		and state.get("gravity_world_m_s2") == direct.get("gravity_world_m_s2")
		and Epoch._from_vec(direct.get("gravity_world_m_s2")) == Epoch._from_vec(frame.ordered_body_sources[0].total_gravity_world_m_s2)
		and base.get("outer_step_duration_s") == frame.ordered_body_sources[0].solver_step_s)


static func _energy_join(sdk: Object, epoch: Dictionary, energy: Dictionary, sources: Dictionary) -> bool:
	if not Epoch._digest_matches(sdk,epoch) or not Epoch._digest_matches(sdk,energy) or not Epoch._digest_matches(sdk,sources): return false
	if epoch.get("ok") != true or energy.get("ok") != true or sources.get("ok") != true: return false
	if not (epoch.get("state_after") is Dictionary) or not (energy.get("state_after") is Dictionary): return false
	if not Epoch.state_valid_v1(sdk,epoch.state_after) or not Energy.state_valid_v1(sdk,energy.state_after): return false
	var projected := Energy.project_sources_v1(sdk,sources.context,epoch.state_after.latest,sources.raw)
	if projected.get("ok") != true or projected != sources: return false
	return (energy.state_after.epoch_state_sha256 == epoch.state_after.payload_sha256
		and energy.measured_sources_sha256 == sources.payload_sha256 and sources.frame_sha256 == epoch.state_after.latest.payload_sha256
		and energy.state_after.increment_count == epoch.state_after.observed_pair_count
		and energy.energy_increment.semantic_step == epoch.state_after.latest.completed_boundary.boundary_sequence)


static func _sha(sdk: Object, value: Variant) -> String:
	return World._sha256(sdk,Epoch.json_safe_v1(value))


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": "LIVE_RECOVERY_OBSERVATION_"+code, "world_build_count": 0,
		"solver_step_count": 0, "physics_state_modified": false, "physical_acceptance_authority": false, "release_authority": false}
