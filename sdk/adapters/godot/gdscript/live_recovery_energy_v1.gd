extends RefCounted
## Measured work after a fresh completed boundary. Each channel is accumulated
## once from its own source; uncollected walking history is never reconstructed.
const Epoch := preload("res://sdk/adapters/godot/gdscript/live_recovery_epoch_v1.gd")
const World := Epoch.World
const Rotation := World.RotationAwareEnergyLedgerScript
const Calls := preload("res://sdk/adapters/godot/gdscript/r10k_partial_recovery_stage_v1.gd")
const STATE := "sporespore_live_recovery_energy_state_v1"
const SOURCES := "sporespore_live_recovery_energy_sources_v1"
const TRANSITION := "sporespore_live_recovery_energy_transition_v1"
const CHANNELS := ["applied_actuator_work_j", "signed_external_work_j", "signed_constraint_exchange_j",
	"signed_discrete_staging_exchange_j", "passive_dissipation_j"]
const CONTEXT_KEYS := ["rotation_aware_energy_ledger_profile_selected", "recovery_energy_ledger_profile_id",
	"capability_variant_id", "adapter_energy_mapping_profile_id", "solver_energy_consumer_contract_schema_version",
	"solver_energy_telemetry_schema_version", "solver_energy_telemetry_profile_id", "r24d161_diagnosis_raw_sha256",
	"partition_rule_id", "complete_energy_profile_selected", "solver_coupled_complete_energy_profile_selected",
	"discrete_staging_complete_energy_profile_selected"]


static func capture_sources_v1(sdk: Object, context: Dictionary, model: Dictionary, frame: Dictionary,
	no_actuation_requested: bool, external_events: Array) -> Dictionary:
	if not Epoch.frame_valid_v1(sdk, frame) or model.get("ok") != true: return _failure("FRAME_OR_MODEL")
	var bodies: Array = []
	var joints: Array = []
	var motors: Array = []
	for index in range(9):
		var id: String = World.ORDERED_BODY_IDS[index]
		var body: Variant = model.body_nodes.get(id)
		if not (body is RigidBody3D) or not is_instance_valid(body): return _failure("BODY")
		if body.get_instance_id() != frame.ordered_body_sources[index].instance_id: return _failure("BODY_INSTANCE")
		bodies.append({"body_id": id, "total_gravity_world_m_s2": Epoch._from_vec(frame.ordered_body_sources[index].total_gravity_world_m_s2),
			"linear_damp_mode": int(body.linear_damp_mode), "angular_damp_mode": int(body.angular_damp_mode),
			"linear_damp": float(body.linear_damp), "angular_damp": float(body.angular_damp), "continuous_cd": bool(body.continuous_cd)})
	for index in range(8):
		var id: String = World.ORDERED_JOINT_IDS[index]
		var actuator: String = World.ORDERED_ACTUATOR_IDS[index]
		var joint: Variant = model.joint_nodes.get(id)
		if not (joint is HingeJoint3D) or not is_instance_valid(joint): return _failure("JOINT")
		joints.append({"joint_id": id, "motor_enabled": bool(joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR))})
		motors.append({"joint_id": id, "actuator_id": actuator, "joint_instance_id": joint.get_instance_id(),
			"published_cap_nms": float(model.blueprint.cap_by_actuator_id[actuator].maximum_outer_step_impulse_nms),
			"target_velocity_readback_rad_s": float(joint.get_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY)),
			"maximum_impulse_readback_nms": float(joint.get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE)),
			"telemetry": JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(joint.get_rid())})
	var space: World3D = model.body_nodes.torso.get_world_3d()
	if space == null: return _failure("SPACE")
	var solver: Variant = ClassDB.class_call_static(&"JoltPhysicsServer3D", &"space_get_solver_energy_exchange_telemetry", space.space)
	return project_sources_v1(sdk, context, frame, {"ordered_body_readbacks": bodies, "ordered_joint_readbacks": joints,
		"ordered_motor_sources": motors, "solver_telemetry": solver, "no_actuation_requested": no_actuation_requested,
		"external_events": external_events.duplicate(true)})


## The native capture and synthetic controls share this exact source consumer.
static func project_sources_v1(sdk: Object, context: Dictionary, frame: Dictionary, raw: Dictionary) -> Dictionary:
	if not Rotation.context_authority_exact_v1(context) or not Epoch.frame_valid_v1(sdk, frame): return _failure("CONTEXT_OR_FRAME")
	for item in [["ordered_body_readbacks", 9], ["ordered_joint_readbacks", 8], ["ordered_motor_sources", 8]]:
		if not (raw.get(item[0]) is Array) or raw[item[0]].size() != item[1]: return _failure("SOURCE_POPULATION")
	if typeof(raw.get("no_actuation_requested")) != TYPE_BOOL or not (raw.get("external_events") is Array): return _failure("INPUT_POLICY")
	# This route commissions the existing zero-external-work profile. An event
	# during a collected interval is refused, never silently assigned zero work.
	if not raw.external_events.is_empty(): return _failure("EXTERNAL_EVENT_DURING_COLLECTION")
	var native_step: int = frame.native_space_step_sequence
	var global_step: int = frame.completed_boundary.boundary_sequence
	var dt := NAN
	var work := 0.0
	var receipts: Array = []
	var joint_instances: Array = []
	for index in range(8):
		var source: Variant = raw.ordered_motor_sources[index]
		if not (source is Dictionary): return _failure("MOTOR_SOURCE")
		var actuator: String = World.ORDERED_ACTUATOR_IDS[index]
		if (source.get("actuator_id") != actuator or source.get("joint_id") != World.ORDERED_JOINT_IDS[index]
			or typeof(source.get("joint_instance_id")) != TYPE_INT or source.joint_instance_id <= 0
			or joint_instances.has(source.joint_instance_id)): return _failure("MOTOR_IDENTITY")
		for key in ["published_cap_nms", "target_velocity_readback_rad_s", "maximum_impulse_readback_nms"]:
			if typeof(source.get(key)) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(source[key]): return _failure("MOTOR_READBACK")
		if source.maximum_impulse_readback_nms < 0.0 or source.maximum_impulse_readback_nms > source.published_cap_nms: return _failure("MOTOR_CAP")
		joint_instances.append(source.joint_instance_id)
		var projection := World.native_motor_work_projection_v1(source.get("telemetry"), actuator)
		if projection.get("ok") != true: return projection
		var contract := World.native_motor_telemetry_contract_v2(projection.telemetry, actuator, source.published_cap_nms,
			raw.no_actuation_requested, native_step, dt)
		if contract.get("ok") != true: return contract
		dt = contract.solver_step_s; work += contract.net_motor_work_j
		var row := {"actuator_id": actuator, "joint_id": source.joint_id,
			"capture_space_step_sequence": contract.capture_space_step_sequence, "read_space_step_sequence": contract.read_space_step_sequence,
			"solver_step_s": dt, "signed_motor_impulse_nms": contract.signed_motor_impulse_nms,
			"positive_motor_work_j": contract.positive_motor_work_j, "absorbed_motor_work_j": contract.absorbed_motor_work_j,
			"net_motor_work_j": contract.net_motor_work_j, "native_net_motor_work_j": source.telemetry.net_motor_work_j,
			"actuator_mapping_id": World.R144_SOLVER_COUPLED_COMPLETE_ENERGY_ACTUATOR_MAPPING_ID,
			"work_mapping_id": World.R144_SOLVER_COUPLED_COMPLETE_ENERGY_WORK_MAPPING_ID,
			"source_measurement": true, "mechanical_energy_residual_used_as_work_source": false}
		receipts.append(row)
	if not is_finite(work) or absf(dt - World.OUTER_STEP_DURATION_S) > 1.0e-9: return _failure("STEP_TIME_OR_WORK")
	for index in range(9):
		var body: Variant = raw.ordered_body_readbacks[index]
		if not (body is Dictionary) or body.get("total_gravity_world_m_s2") != Epoch._from_vec(frame.ordered_body_sources[index].total_gravity_world_m_s2): return _failure("GRAVITY_SOURCE_JOIN")
	var inputs := World.solver_coupled_complete_energy_partition_inputs_contract_v1({"semantic_step": global_step,
		"ordered_body_readbacks": raw.ordered_body_readbacks, "ordered_joint_readbacks": raw.ordered_joint_readbacks,
		"no_actuation_requested": raw.no_actuation_requested,
		"actuator_mapping_id": "" if raw.no_actuation_requested else World.R144_SOLVER_COUPLED_COMPLETE_ENERGY_ACTUATOR_MAPPING_ID,
		"work_mapping_id": "" if raw.no_actuation_requested else World.R144_SOLVER_COUPLED_COMPLETE_ENERGY_WORK_MAPPING_ID,
		"step_actuator_work_j": work, "external_intervention_event_count": 0, "step_signed_external_work_j": 0.0,
		"adapter_side_discrete_staging_event_count": 0, "step_signed_discrete_staging_exchange_j": 0.0})
	if inputs.get("ok") != true: return inputs
	var solver := World.native_solver_energy_exchange_for_recovery_route_v2(context, raw.get("solver_telemetry"), native_step,
		Epoch._from_vec(frame.ordered_body_sources[0].total_gravity_world_m_s2))
	if solver.get("ok") != true: return solver
	for key in frame.solver_energy_source:
		if solver.get(key) != frame.solver_energy_source[key]: return _failure("SOLVER_SOURCE_JOIN")
	var partition := World.solver_coupled_complete_energy_partition_for_recovery_route_v2(context, solver, receipts, work, native_step)
	if partition.get("ok") != true: return partition
	return Epoch._seal(sdk, {"schema_version": SOURCES, "ok": true, "frame_sha256": frame.payload_sha256,
		"context": _context(context), "global_step": global_step, "native_step": native_step,
		"raw": raw.duplicate(true), "joint_instances": joint_instances, "motor_receipts": receipts,
		"partition_inputs": inputs, "solver_receipt": solver, "constraint_partition": partition,
		"physics_state_modified": false, "physical_acceptance_authority": false, "release_authority": false})


static func begin_v1(sdk: Object, context: Dictionary, epoch: Dictionary) -> Dictionary:
	if not Rotation.context_authority_exact_v1(context) or not Epoch.state_valid_v1(sdk, epoch) or epoch.observed_pair_count != 0: return _failure("ORIGIN")
	var energy: float = epoch.origin.mechanical_energy_j
	var ledger := {"schema_version": "sporespore_recovery_energy_balance_ledger_v3",
		"equation_id": "current_minus_initial_minus_actuator_minus_external_minus_constraint_minus_discrete_staging_plus_passive_v3",
		"component_partition_id": "sporespore_disjoint_actuator_external_constraint_discrete_staging_passive_energy_partition_v3",
		"source_profile_id": Epoch.Staging.MAPPING_PROFILE_ID, "source_values_sha256": epoch.origin.payload_sha256,
		"initial_mechanical_energy_j": energy, "current_mechanical_energy_j": energy, "source_measurement": true}
	for key in CHANNELS: ledger["cumulative_" + key] = 0.0
	var state := {"schema_version": STATE, "epoch_id": epoch.epoch_id, "origin_global_step": epoch.origin.completed_boundary.boundary_sequence,
		"last_global_step": epoch.origin.completed_boundary.boundary_sequence, "increment_count": 0,
		"epoch_state_sha256": epoch.payload_sha256, "context_sha256": World._sha256(sdk, _context(context)),
		"joint_instances": [], "ledger": ledger, "unobserved_history_claimed": false,
		"physical_acceptance_authority": false, "release_authority": false}
	return {"ok": true, "state": Epoch._seal(sdk, state), "world_build_count": 0, "solver_step_count": 0, "physics_state_modified": false}


static func advance_v1(sdk: Object, state: Dictionary, epoch_transition: Dictionary, sources: Dictionary) -> Dictionary:
	if not state_valid_v1(sdk, state) or not Epoch._digest_matches(sdk, epoch_transition) or epoch_transition.get("ok") != true: return _failure("STATE_OR_TRANSITION")
	var epoch: Variant = epoch_transition.get("state_after")
	if not (epoch is Dictionary) or not Epoch.state_valid_v1(sdk, epoch): return _failure("EPOCH")
	if (epoch_transition.get("state_before_sha256") != state.epoch_state_sha256 or epoch.epoch_id != state.epoch_id
		or epoch.observed_pair_count != state.increment_count + 1
		or epoch.latest.completed_boundary.boundary_sequence != state.last_global_step + 1): return _failure("STEP_JOIN")
	if not Epoch._digest_matches(sdk, sources) or sources.get("schema_version") != SOURCES or not (sources.get("context") is Dictionary) or not (sources.get("raw") is Dictionary): return _failure("SOURCES")
	if World._sha256(sdk, sources.context) != state.context_sha256: return _failure("CONTEXT_CHANGED")
	var reconstructed := project_sources_v1(sdk, sources.context, epoch.latest, sources.raw)
	if reconstructed != sources: return _failure("SOURCE_RECONSTRUCTION")
	if state.increment_count > 0 and state.joint_instances != sources.joint_instances: return _failure("JOINT_REPLACED")
	var increment := {"sequence_index": epoch.observed_pair_count, "semantic_step": epoch.latest.completed_boundary.boundary_sequence,
		"applied_actuator_work_j": sources.constraint_partition.step_actuator_work_j,
		"signed_constraint_exchange_j": sources.constraint_partition.step_signed_constraint_exchange_j,
		"signed_discrete_staging_exchange_j": epoch_transition.staging_observer_receipt.signed_discrete_staging_exchange_j,
		"signed_external_work_j": sources.partition_inputs.step_signed_external_work_j,
		"passive_dissipation_j": sources.partition_inputs.step_passive_dissipation_j, "source_measurement": true}
	var ledger: Dictionary = state.ledger.duplicate(true)
	ledger.current_mechanical_energy_j = epoch.latest.mechanical_energy_j
	for key in CHANNELS:
		ledger["cumulative_" + key] += increment[key]
		if not is_finite(ledger["cumulative_" + key]): return _failure("NONFINITE_ACCUMULATOR")
	var source_chain := {"previous_source_values_sha256": state.ledger.source_values_sha256,
		"epoch_transition_sha256": epoch_transition.payload_sha256, "measured_sources_sha256": sources.payload_sha256,
		"energy_increment": increment, "current_mechanical_energy_j": ledger.current_mechanical_energy_j}
	ledger.source_values_sha256 = World._sha256(sdk, source_chain)
	var evaluated := Calls.call_v1(sdk, "recovery_energy_balance_evaluate_v3_json",
		{"schema_version": "sporespore_recovery_energy_balance_evaluation_request_v3", "ledger": ledger})
	if evaluated.get("ok") != true or evaluated.value.get("support_status") != "supported_exact": return _failure("PORTABLE_LEDGER_REFUSED", evaluated)
	var next := state.duplicate(true)
	next.ledger = ledger; next.increment_count += 1; next.last_global_step = increment.semantic_step
	next.epoch_state_sha256 = epoch.payload_sha256; next.joint_instances = sources.joint_instances.duplicate()
	return Epoch._seal(sdk, {"schema_version": TRANSITION, "ok": true, "state_before_sha256": state.payload_sha256,
		"state_after": Epoch._seal(sdk, next), "energy_increment": increment, "source_chain": source_chain,
		"measured_sources_sha256": sources.payload_sha256, "portable_evaluation_call": evaluated,
		"complete_measured_energy_partition": true, "controller_command_emitted": false,
		"world_build_count": 0, "solver_step_count": 0, "physics_state_modified": false,
		"physical_acceptance_authority": false, "release_authority": false})


static func state_valid_v1(sdk: Object, state: Dictionary) -> bool:
	if state.get("schema_version") != STATE or not Epoch._digest_matches(sdk, state): return false
	if typeof(state.get("increment_count")) != TYPE_INT or state.increment_count < 0: return false
	if typeof(state.get("origin_global_step")) != TYPE_INT or typeof(state.get("last_global_step")) != TYPE_INT: return false
	if state.origin_global_step <= 0 or state.last_global_step != state.origin_global_step + state.increment_count: return false
	if typeof(state.get("epoch_id")) != TYPE_STRING or state.epoch_id.is_empty(): return false
	for key in ["epoch_state_sha256", "context_sha256"]:
		if typeof(state.get(key)) != TYPE_STRING or not state[key].begins_with("sha256:") or state[key].length() != 71: return false
	if not (state.get("ledger") is Dictionary) or not (state.get("joint_instances") is Array): return false
	if state.joint_instances.size() != (0 if state.increment_count == 0 else 8): return false
	var seen := {}
	for instance in state.joint_instances:
		if typeof(instance) != TYPE_INT or instance <= 0 or seen.has(instance): return false
		seen[instance] = true
	if state.ledger.get("schema_version") != "sporespore_recovery_energy_balance_ledger_v3": return false
	if state.ledger.get("equation_id") != "current_minus_initial_minus_actuator_minus_external_minus_constraint_minus_discrete_staging_plus_passive_v3": return false
	if state.ledger.get("component_partition_id") != "sporespore_disjoint_actuator_external_constraint_discrete_staging_passive_energy_partition_v3": return false
	if state.ledger.get("source_profile_id") != Epoch.Staging.MAPPING_PROFILE_ID or state.ledger.get("source_measurement") != true: return false
	if typeof(state.ledger.get("source_values_sha256")) != TYPE_STRING or not state.ledger.source_values_sha256.begins_with("sha256:") or state.ledger.source_values_sha256.length() != 71: return false
	for key in ["initial_mechanical_energy_j", "current_mechanical_energy_j"]:
		if typeof(state.ledger.get(key)) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(state.ledger[key]): return false
	for key in CHANNELS:
		if typeof(state.ledger.get("cumulative_" + key)) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(state.ledger["cumulative_" + key]): return false
		if state.increment_count == 0 and state.ledger["cumulative_" + key] != 0.0: return false
	if state.ledger.cumulative_passive_dissipation_j < 0.0: return false
	if state.increment_count == 0 and state.ledger.initial_mechanical_energy_j != state.ledger.current_mechanical_energy_j: return false
	for key in ["unobserved_history_claimed", "physical_acceptance_authority", "release_authority"]:
		if state.get(key) != false: return false
	return true


static func _context(value: Dictionary) -> Dictionary:
	var result := {}
	for key in CONTEXT_KEYS: result[key] = value.get(key)
	return result


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {"ok": false, "failure_code": "LIVE_RECOVERY_ENERGY_" + code, "detail": detail,
		"world_build_count": 0, "solver_step_count": 0, "physics_state_modified": false,
		"physical_acceptance_authority": false, "release_authority": false}
