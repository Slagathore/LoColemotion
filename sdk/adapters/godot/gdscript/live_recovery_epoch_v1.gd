extends RefCounted
## Fresh observation ownership after a gap in recovery collection. Native
## clocks and bodies keep their identities; only this observer's count starts
## at zero. This boundary does not grant a complete recovery energy partition.
const World := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const Boundary := preload("res://sdk/adapters/godot/gdscript/recovery_contiguous_boundary_transport_v1.gd")
const Solver := preload("res://sdk/adapters/godot/gdscript/recovery_solver_energy_exchange_v2.gd")
const Staging := preload("res://sdk/adapters/godot/gdscript/recovery_discrete_staging_route_v1.gd")
const FRAME := "sporespore_live_recovery_completed_boundary_v1"
const STATE := "sporespore_live_recovery_observation_epoch_v1"


## Native entrypoint. Read the current callbacks and solver snapshot without
## changing the old recovery collector, a transform, velocity or motor.
static func capture_v1(sdk: Object, model: Dictionary, completed_step: int, native_sequence: int) -> Dictionary:
	if sdk == null or model.get("ok") != true or not (model.get("body_nodes") is Dictionary):
		return _failure("MODEL")
	var old: Variant = model.get("contiguous_boundary_transport_state")
	if not (old is Dictionary) or not Boundary.state_valid_v1(sdk, old):
		return _failure("MODEL_IDENTITY")
	var identity := {}
	for key in ["attempt_id", "arm_id", "model_instance_id"]: identity[key] = old[key]
	var snapshots := {}
	var instances: Array = []
	for id in Boundary.ORDERED_BODY_IDS:
		var body: Variant = model.body_nodes.get(id)
		if not (body is RigidBody3D) or not is_instance_valid(body): return _failure("BODY_MISSING")
		if body.get("semantic_contact_callback_count") != completed_step: return _failure("CONTACT_CLOCK")
		# The qualified staging observer requires no extra applied body forces.
		if (body.constant_force != Vector3.ZERO or body.constant_torque != Vector3.ZERO
			or body.custom_integrator or body.gravity_scale != 1.0 or body.can_sleep or body.sleeping or body.freeze
			or body.axis_lock_linear_x or body.axis_lock_linear_y or body.axis_lock_linear_z
			or body.linear_damp_mode != RigidBody3D.DAMP_MODE_REPLACE or body.angular_damp_mode != RigidBody3D.DAMP_MODE_REPLACE
			or body.continuous_cd or body.linear_damp != 0.0 or body.angular_damp != 0.0):
			return _failure("BODY_FORCE_PROFILE")
		snapshots[id] = body.get("latest_direct_state_snapshot")
		instances.append(body.get_instance_id())
	var space: World3D = model.body_nodes.torso.get_world_3d()
	if space == null: return _failure("SPACE")
	var telemetry: Variant = ClassDB.class_call_static(&"JoltPhysicsServer3D",
		&"space_get_solver_energy_exchange_telemetry", space.space)
	return project_v1(sdk, identity, snapshots, instances, completed_step, native_sequence, telemetry)


## Shared by live capture and synthetic controls. Every numerical source is
## retained so an independent reader can rebuild the boundary and energy.
static func project_v1(sdk: Object, identity: Dictionary, snapshots: Dictionary, instances: Array,
	completed_step: int, native_sequence: int, telemetry: Variant) -> Dictionary:
	if sdk == null or completed_step <= 0 or native_sequence <= 0 or snapshots.size() != 9 or instances.size() != 9:
		return _failure("SOURCE_POPULATION")
	if identity.size() != 3: return _failure("IDENTITY")
	for key in ["attempt_id", "arm_id", "model_instance_id"]:
		if typeof(identity.get(key)) != TYPE_STRING or identity[key].is_empty(): return _failure("IDENTITY")
	var seen := {}
	var ordered: Array = []
	var sources: Array = []
	var gravity := Vector3.ZERO
	var dt := 0.0
	for index in range(9):
		var id: String = Boundary.ORDERED_BODY_IDS[index]
		var s: Variant = snapshots.get(id)
		if not (s is Dictionary) or not _snapshot_valid(s, completed_step): return _failure("CALLBACK_SOURCE")
		if typeof(instances[index]) != TYPE_INT or instances[index] <= 0 or seen.has(instances[index]): return _failure("BODY_INSTANCE")
		seen[instances[index]] = true
		if index == 0:
			gravity = s.total_gravity_world_m_s2; dt = s.solver_step_s
		elif s.total_gravity_world_m_s2 != gravity or s.solver_step_s != dt:
			return _failure("BODY_SOLVER_PROFILE")
		ordered.append({"body_id": id, "body_index": index, "boundary_sequence": completed_step,
			"position_world_m": s.transform.origin, "linear_velocity_world_m_s": s.linear_velocity_world_m_s,
			"mass_kg": s.mass_kg, "callback_sequence": s.callback_sequence,
			"total_gravity_world_m_s2": gravity, "solver_step_s": dt})
		sources.append({"body_id": id, "instance_id": instances[index], "callback_sequence": s.callback_sequence,
			"position_world_m": _vec(s.transform.origin), "orientation_basis": _basis(s.transform.basis),
			"linear_velocity_world_m_s": _vec(s.linear_velocity_world_m_s),
			"angular_velocity_world_rad_s": _vec(s.angular_velocity_world_rad_s),
			"inverse_inertia_tensor_world_kg_inv_m2": _basis(s.inverse_inertia_tensor_world_kg_inv_m2),
			"mass_kg": s.mass_kg, "total_gravity_world_m_s2": _vec(gravity), "solver_step_s": dt})
	var boundary := Boundary.build_completed_step_boundary_v1(sdk, identity.attempt_id, identity.arm_id,
		identity.model_instance_id, completed_step, "live:%s:%s:%s:%d" % [identity.attempt_id,
		identity.arm_id, identity.model_instance_id, completed_step], ordered)
	if boundary.get("ok") != true: return boundary
	var solver := Solver.native_solver_energy_exchange_contract_v2(telemetry, native_sequence, gravity)
	if solver.get("ok") != true: return solver
	var mechanical := World._mechanical_energy_j({}, snapshots)
	if not is_finite(mechanical): return _failure("MECHANICAL_ENERGY")
	return _seal(sdk, {"schema_version": FRAME, "ok": true, "completed_boundary": boundary.boundary,
		"ordered_body_sources": sources, "native_space_step_sequence": native_sequence,
		"solver_energy_source": solver, "mechanical_energy_j": mechanical,
		"source_measurement": true, "physics_state_modified": false,
		"complete_recovery_energy_partition": false, "physical_acceptance_authority": false, "release_authority": false})


static func begin_v1(sdk: Object, frame: Dictionary, epoch_id: String, trigger_source_sha256: String) -> Dictionary:
	if not frame_valid_v1(sdk, frame) or epoch_id.is_empty() or not Boundary._digest_valid_v1(trigger_source_sha256):
		return _failure("INITIAL_BOUNDARY")
	var state := {"schema_version": STATE, "epoch_id": epoch_id, "trigger_source_sha256": trigger_source_sha256,
		"origin": frame.duplicate(true), "latest": frame.duplicate(true), "observed_pair_count": 0,
		"cumulative_signed_discrete_staging_exchange_j": 0.0,
		"unobserved_pre_epoch_history_claimed": false, "global_sequence_rewritten": false,
		"complete_recovery_energy_partition": false, "physical_acceptance_authority": false, "release_authority": false}
	return {"ok": true, "state": _seal(sdk, state), "world_build_count": 0, "solver_step_count": 0,
		"physics_state_modified": false, "recovery_command_emitted": false}


static func advance_v1(sdk: Object, state: Dictionary, frame: Dictionary) -> Dictionary:
	if not state_valid_v1(sdk, state) or not frame_valid_v1(sdk, frame): return _failure("STATE_OR_FRAME")
	var before: Dictionary = state.latest.completed_boundary
	var after: Dictionary = frame.completed_boundary
	for key in ["attempt_id", "arm_id", "model_instance_id"]:
		if before[key] != after[key]: return _failure("CROSSED_IDENTITY")
	if after.boundary_sequence != before.boundary_sequence + 1: return _failure("NONCONTIGUOUS_CALLBACK")
	if frame.native_space_step_sequence != state.latest.native_space_step_sequence + 1: return _failure("NONCONTIGUOUS_SOLVER")
	var pairs: Array = []
	for index in range(9):
		var first: Dictionary = before.ordered_bodies[index]
		var last: Dictionary = after.ordered_bodies[index]
		var old_source: Dictionary = state.latest.ordered_body_sources[index]
		var new_source: Dictionary = frame.ordered_body_sources[index]
		for key in ["body_id", "instance_id", "mass_kg", "total_gravity_world_m_s2", "solver_step_s"]:
			if old_source[key] != new_source[key]: return _failure("BODY_OR_PROFILE_CHANGED")
		pairs.append({"body_id": first.body_id, "body_index": index,
			"pre_boundary_sequence": before.boundary_sequence, "post_boundary_sequence": after.boundary_sequence,
			"pre_source_event_id": before.source_event_id, "post_source_event_id": after.source_event_id,
			"mass_kg": first.mass_kg, "pre_position_world_m": first.position_world_m, "post_position_world_m": last.position_world_m,
			"pre_linear_velocity_world_m_s": first.linear_velocity_world_m_s, "post_linear_velocity_world_m_s": last.linear_velocity_world_m_s,
			"total_gravity_world_m_s2": last.total_gravity_world_m_s2, "solver_step_s": last.solver_step_s,
			"pre_source_measurement": true, "post_source_measurement": true})
	var displacement: Dictionary = frame.solver_energy_source.position_constraint_mass_weighted_displacement_kg_m
	var observed := Staging.measure_native_step_v1(after.boundary_sequence, before.boundary_sequence,
		frame.ordered_body_sources[0].solver_step_s, pairs, Vector3(displacement.x, displacement.y, displacement.z))
	if observed.get("ok") != true: return observed
	var next := state.duplicate(true)
	next.latest = frame.duplicate(true); next.observed_pair_count += 1
	next.cumulative_signed_discrete_staging_exchange_j += observed.signed_discrete_staging_exchange_j
	if not is_finite(next.cumulative_signed_discrete_staging_exchange_j): return _failure("ACCUMULATOR_NONFINITE")
	return _seal(sdk, {"schema_version": "sporespore_live_recovery_observation_epoch_advance_v1", "ok": true,
		"state_before_sha256": state.payload_sha256, "state_after": _seal(sdk, next),
		"completed_global_step": after.boundary_sequence, "epoch_local_step": next.observed_pair_count,
		"boundary_pairs": pairs, "staging_observer_receipt": observed,
		"input_state_mutated": false, "world_build_count": 0, "solver_step_count": 0,
		"physics_state_modified": false, "recovery_command_emitted": false,
		"complete_recovery_energy_partition": false, "physical_acceptance_authority": false, "release_authority": false})


static func frame_valid_v1(sdk: Object, frame: Dictionary) -> bool:
	if (frame.get("schema_version") != FRAME or frame.get("ok") != true or not _digest_matches(sdk, frame)
		or not (frame.get("completed_boundary") is Dictionary) or not (frame.get("ordered_body_sources") is Array)
		or frame.ordered_body_sources.size() != 9 or not (frame.get("solver_energy_source") is Dictionary)
		or typeof(frame.get("native_space_step_sequence")) != TYPE_INT or frame.native_space_step_sequence <= 0
		or typeof(frame.get("mechanical_energy_j")) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(frame.mechanical_energy_j)):
		return false
	if not Boundary.boundary_valid_v1(sdk, frame.completed_boundary, Boundary.COMPLETED_STEP_SOURCE_KIND): return false
	var rebuilt := {}
	var seen := {}
	for index in range(9):
		var source: Variant = frame.ordered_body_sources[index]
		if not (source is Dictionary): return false
		var body: Dictionary = frame.completed_boundary.ordered_bodies[index]
		if (source.get("body_id") != Boundary.ORDERED_BODY_IDS[index] or source.get("callback_sequence") != frame.completed_boundary.boundary_sequence
			or typeof(source.get("instance_id")) != TYPE_INT or source.instance_id <= 0 or seen.has(source.instance_id)
			or source.get("mass_kg") != body.mass_kg or source.get("solver_step_s") != body.solver_step_s): return false
		seen[source.instance_id] = true
		for key in ["position_world_m", "linear_velocity_world_m_s", "angular_velocity_world_rad_s", "total_gravity_world_m_s2"]:
			if not _vector_valid(source.get(key)): return false
		for key in ["orientation_basis", "inverse_inertia_tensor_world_kg_inv_m2"]:
			if not (source.get(key) is Array) or source[key].size() != 3: return false
			for axis in source[key]:
				if not _vector_valid(axis): return false
		for key in ["position_world_m", "linear_velocity_world_m_s", "total_gravity_world_m_s2"]:
			if _from_vec(source[key]) != body[key]: return false
		rebuilt[source.body_id] = {"transform": Transform3D(_from_basis(source.orientation_basis), _from_vec(source.position_world_m)),
			"linear_velocity_world_m_s": _from_vec(source.linear_velocity_world_m_s), "angular_velocity_world_rad_s": _from_vec(source.angular_velocity_world_rad_s),
			"total_gravity_world_m_s2": _from_vec(source.total_gravity_world_m_s2),
			"inverse_inertia_tensor_world_kg_inv_m2": _from_basis(source.inverse_inertia_tensor_world_kg_inv_m2), "mass_kg": source.mass_kg}
	if World._mechanical_energy_j({}, rebuilt) != frame.mechanical_energy_j: return false
	if (frame.solver_energy_source.get("ok") != true
		or frame.solver_energy_source.get("capture_space_step_sequence") != frame.native_space_step_sequence
		or frame.solver_energy_source.get("read_space_step_sequence") != frame.native_space_step_sequence): return false
	for key in ["physics_state_modified", "complete_recovery_energy_partition", "physical_acceptance_authority", "release_authority"]:
		if frame.get(key) != false: return false
	return frame.get("source_measurement") == true


static func state_valid_v1(sdk: Object, state: Dictionary) -> bool:
	if (state.get("schema_version") != STATE or not _digest_matches(sdk, state)
		or typeof(state.get("epoch_id")) != TYPE_STRING or state.epoch_id.is_empty()
		or typeof(state.get("trigger_source_sha256")) != TYPE_STRING or not Boundary._digest_valid_v1(state.trigger_source_sha256)
		or not (state.get("origin") is Dictionary) or not (state.get("latest") is Dictionary)
		or typeof(state.get("observed_pair_count")) != TYPE_INT or state.observed_pair_count < 0
		or typeof(state.get("cumulative_signed_discrete_staging_exchange_j")) not in [TYPE_FLOAT, TYPE_INT]
		or not is_finite(state.cumulative_signed_discrete_staging_exchange_j)):
		return false
	if not frame_valid_v1(sdk, state.origin) or not frame_valid_v1(sdk, state.latest): return false
	for key in ["attempt_id", "arm_id", "model_instance_id"]:
		if state.origin.completed_boundary[key] != state.latest.completed_boundary[key]: return false
	if (state.latest.completed_boundary.boundary_sequence - state.origin.completed_boundary.boundary_sequence != state.observed_pair_count
		or state.latest.native_space_step_sequence - state.origin.native_space_step_sequence != state.observed_pair_count): return false
	if state.observed_pair_count == 0 and (state.origin != state.latest or state.cumulative_signed_discrete_staging_exchange_j != 0.0): return false
	for index in range(9):
		for key in ["body_id", "instance_id", "mass_kg", "total_gravity_world_m_s2", "solver_step_s"]:
			if state.origin.ordered_body_sources[index][key] != state.latest.ordered_body_sources[index][key]: return false
	for key in ["unobserved_pre_epoch_history_claimed", "global_sequence_rewritten", "complete_recovery_energy_partition", "physical_acceptance_authority", "release_authority"]:
		if state.get(key) != false: return false
	return true


static func _snapshot_valid(s: Dictionary, step: int) -> bool:
	if typeof(s.get("callback_sequence")) != TYPE_INT or s.get("callback_sequence") != step or s.get("source_measurement") != true or not (s.get("transform") is Transform3D): return false
	for key in ["linear_velocity_world_m_s", "angular_velocity_world_rad_s", "total_gravity_world_m_s2"]:
		if not (s.get(key) is Vector3) or not s[key].is_finite(): return false
	if not (s.get("inverse_inertia_tensor_world_kg_inv_m2") is Basis): return false
	for basis in [s.transform.basis, s.inverse_inertia_tensor_world_kg_inv_m2]:
		if not basis.x.is_finite() or not basis.y.is_finite() or not basis.z.is_finite(): return false
	return (s.transform.origin.is_finite() and typeof(s.get("mass_kg")) in [TYPE_FLOAT, TYPE_INT]
		and is_finite(s.mass_kg) and s.mass_kg > 0.0 and typeof(s.get("solver_step_s")) in [TYPE_FLOAT, TYPE_INT]
		and is_finite(s.solver_step_s) and s.solver_step_s > 0.0)


static func _seal(sdk: Object, value: Dictionary) -> Dictionary:
	var result := value.duplicate(true); result.erase("payload_sha256")
	result["payload_sha256"] = World._sha256(sdk, json_safe_v1(result))
	return result


static func _digest_matches(sdk: Object, value: Dictionary) -> bool:
	return sdk != null and typeof(value.get("payload_sha256")) == TYPE_STRING and Boundary._digest_valid_v1(value.payload_sha256) and _seal(sdk, value).payload_sha256 == value.payload_sha256


static func _vec(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


static func _basis(value: Basis) -> Array:
	return [_vec(value.x), _vec(value.y), _vec(value.z)]


static func _vector_valid(value: Variant) -> bool:
	if not (value is Dictionary) or value.size() != 3: return false
	for key in ["x", "y", "z"]:
		if typeof(value.get(key)) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(value[key]): return false
	return true


static func _from_vec(value: Dictionary) -> Vector3:
	return Vector3(value.x, value.y, value.z)


static func _from_basis(value: Array) -> Basis:
	return Basis(_from_vec(value[0]), _from_vec(value[1]), _from_vec(value[2]))


static func json_safe_v1(value: Variant) -> Variant:
	# Match the qualified boundary's exact numeric vector transport. Default
	# JSON formatting of a Vector3 would retain a display string instead.
	if value is Vector3: return [value.x, value.y, value.z]
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = json_safe_v1(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value: result.append(json_safe_v1(item))
		return result
	return value


static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "failure_code": "LIVE_RECOVERY_EPOCH_" + reason,
		"world_build_count": 0, "solver_step_count": 0, "physics_state_modified": false,
		"physical_acceptance_authority": false, "release_authority": false}
