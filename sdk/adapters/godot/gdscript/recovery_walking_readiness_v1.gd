extends RefCounted
## Pure entry-domain calculation. Native provenance is checked by the caller.
## Scalar binary64 arithmetic avoids quantizing retained coordinates to Vector3.
const LIMBS := ["front_left", "front_right", "rear_left", "rear_right"]

static func _vector(v: Dictionary) -> Array:
	var out := []
	for k in ["x", "y", "z"]:
		if typeof(v.get(k)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(v[k]): return []
		out.append(float(v[k]))
	return out

static func _rotate(q: Dictionary, v: Array) -> Array:
	var norm := 0.0
	for k in ["x", "y", "z", "w"]:
		if typeof(q.get(k)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(q[k]): return []
		norm += q[k] * q[k]
	if absf(norm - 1.0) > 1e-6 or v.size() != 3: return []
	var x: float = q.x; var y: float = q.y; var z: float = q.z; var w: float = q.w
	var t := [2.0*(y*v[2]-z*v[1]), 2.0*(z*v[0]-x*v[2]), 2.0*(x*v[1]-y*v[0])]
	var c := [y*t[2]-z*t[1], z*t[0]-x*t[2], x*t[1]-y*t[0]]
	return [v[0]+w*t[0]+c[0], v[1]+w*t[1]+c[1], v[2]+w*t[2]+c[2]]

static func measure_v1(request: Dictionary, com: Dictionary, compiled: Dictionary, limits: Dictionary) -> Dictionary:
	var state: Dictionary = request.get("state", {})
	var frame: Dictionary = request.get("measured_body_frame", {})
	if frame.get("source_measurement") != true: return _failure("FRAME_SOURCE")
	for k in ["semantic_step", "sample_time_s", "adapter_capability_sha256"]:
		if not state.has(k) or frame.get(k) != state[k]: return _failure("FRAME_BINDING")
	var bodies: Array = frame.get("ordered_body_states", [])
	if bodies.size() != 9: return _failure("BODIES")
	var by_id := {}
	for body in bodies:
		if not (body is Dictionary) or by_id.has(body.get("body_id")): return _failure("BODY_ID")
		by_id[body.get("body_id")] = body
	if bodies[0].get("body_id") != "torso" or bodies[0].get("pose_world") != state.get("base_pose_world") or bodies[0].get("twist_world") != state.get("base_twist_world"): return _failure("TORSO_BINDING")
	if compiled.get("descriptor", {}).get("morphology_id") != "qsdk_r05_generated_s169": return _failure("EXACT_S169")
	var g: Dictionary = compiled.get("geometry", {})
	var spec: Dictionary = compiled.get("morphology", {}).get("morphology_spec", {})
	var sites: Array = spec.get("contact_sites", [])
	var actuators: Array = spec.get("actuators", [])
	var contacts: Array = state.get("ordered_contact_observations", [])
	if sites.size() != 4 or contacts.size() != 4 or actuators.size() != 8: return _failure("POPULATION")
	var base: Dictionary = state["base_pose_world"]
	var origin := _vector(base.get("position_m", {}))
	var heading := _rotate(base.get("orientation_xyzw", {}), [0.0, 0.0, 1.0])
	var up := _rotate(base.get("orientation_xyzw", {}), [0.0, 1.0, 0.0])
	var velocity := _vector(com.get("linear_velocity_world_m_s", {}))
	var omega := _vector(state.get("base_twist_world", {}).get("angular_velocity_rad_s", {}))
	if origin.is_empty() or heading.is_empty() or up.is_empty() or velocity.is_empty() or omega.is_empty() or com.get("source_measurement") != true: return _failure("MEASUREMENT")
	var norm := sqrt(heading[0]*heading[0]+heading[2]*heading[2])
	if norm <= 1e-9: return _failure("HEADING")
	var forward := [heading[0]/norm, 0.0, heading[2]/norm]
	var tilt := atan2(sqrt(up[0]*up[0]+up[2]*up[2]), up[1])
	var speed := sqrt(velocity[0]*velocity[0]+velocity[2]*velocity[2])
	var angular := sqrt(omega[0]*omega[0]+omega[1]*omega[1]+omega[2]*omega[2])
	var floor_value: Variant = request.get("floor_reference", {}).get("height_world_m")
	if typeof(floor_value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(floor_value): return _failure("FLOOR")
	for k in ["foot_radius_m", "upper_length_m", "lower_length_m"]:
		if typeof(g.get(k)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(g[k]) or g[k] <= 0: return _failure("DIMENSIONS")
	var upper: float = g.upper_length_m; var lower: float = g.lower_length_m
	var floor_center: float = floor_value + g.foot_radius_m
	var all_bearing := true; var all_feasible := true; var legs := []
	for i in range(4):
		var limb: String = LIMBS[i]
		var site: Dictionary = sites[i]
		var contact: Dictionary = contacts[i]
		if site.get("contact_site_id") != limb+"_foot" or site.get("body_id") != limb+"_distal" or not by_id.has(site.get("body_id")): return _failure("SITE_IDENTITY")
		if contact.get("contact_site_id") != limb+"_foot" or typeof(contact.get("presence")) != TYPE_BOOL or typeof(contact.get("bears_support")) != TYPE_BOOL: return _failure("KNOWN_CONTACT")
		all_bearing = all_bearing and contact.presence and contact.bears_support
		var pose: Dictionary = by_id[site.body_id].get("pose_world", {})
		var position := _vector(pose.get("position_m", {}))
		var offset := _rotate(pose.get("orientation_xyzw", {}), _vector(site.get("local_center_m", {})))
		if position.is_empty() or offset.is_empty(): return _failure("ENDPOINT")
		var x := 0.0
		for j in range(3): x += (position[j]+offset[j]-origin[j])*forward[j]
		x -= g.front_hip_x_m if i < 2 else g.rear_hip_x_m
		var hip: Dictionary = actuators[2*i]; var knee: Dictionary = actuators[2*i+1]
		if hip.get("actuator_id") != limb+"_hip_motor" or knee.get("actuator_id") != limb+"_knee_motor": return _failure("ACTUATOR_ORDER")
		var failures := []; var maximum_reach := 0.0
		for n in range(73):
			var u := n/72.0
			var height: float = origin[1]+u*u*(3.0-2.0*u)*(floor_center+0.33-origin[1])
			var down := height-floor_center
			maximum_reach = maxf(maximum_reach, sqrt(x*x+down*down))
			var cosine := (x*x+down*down-upper*upper-lower*lower)/(2.0*upper*lower)
			if down <= 0.0 or cosine < -1.0 or cosine > 1.0:
				failures.append({"reference_interval": n, "reason": "unreachable_endpoint"})
				continue
			var k := acos(cosine)
			var h := atan2(x, down)-atan2(lower*sin(k), upper+lower*cos(k))
			if h < hip.minimum_target_position_rad or h > hip.maximum_target_position_rad or k < knee.minimum_target_position_rad or k > knee.maximum_target_position_rad:
				failures.append({"reference_interval": n, "reason": "joint_bounds"})
		all_feasible = all_feasible and failures.is_empty()
		legs.append({"limb_id": limb, "sagittal_offset_m": x, "maximum_required_reach_m": maximum_reach,
			"available_leg_length_m": upper+lower, "geometric_path_feasible": failures.is_empty(), "failed_references": failures})
	var checks := {"four_native_supports": all_bearing, "horizontal_com_settled": speed <= limits.maximum_horizontal_com_speed_m_s,
		"angular_settled": angular <= limits.maximum_torso_angular_speed_rad_s, "upright": tilt <= limits.maximum_torso_tilt_rad,
		"zero_bias_reference_path_feasible": all_feasible}
	return {"schema_version": "sporespore_recovery_walking_readiness_v1", "ready": not checks.values().has(false),
		"checks": checks, "ordered_legs": legs, "horizontal_com_speed_m_s": speed, "angular_speed_rad_s": angular,
		"torso_tilt_rad": tilt, "source_semantic_step": state.semantic_step, "reference_height_count": 73,
		"reference_geometry_is_contact_authority": false, "future_contact_guaranteed": false,
		"new_world_count": 0, "new_solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}

static func advance_v1(memory: Dictionary, measurement: Dictionary, limits: Dictionary) -> Dictionary:
	if typeof(memory.get("commands")) != TYPE_INT or memory.commands < 0 or memory.commands >= limits.maximum_commands: return _failure("COMMAND_BOUND")
	if typeof(memory.get("consecutive_ready")) != TYPE_INT or memory.consecutive_ready < 0 or memory.consecutive_ready > memory.commands or typeof(memory.get("last_source_step")) != TYPE_INT or memory.last_source_step < 1: return _failure("MEMORY")
	if memory.get("outcome") != "pending" or typeof(measurement.get("ready")) != TYPE_BOOL: return _failure("TERMINAL_OR_READY")
	if measurement.get("source_semantic_step") != memory.last_source_step+1: return _failure("CONTIGUOUS_SAMPLE")
	var count: int = memory.consecutive_ready+1 if measurement.ready else 0
	var commands: int = memory.commands+1
	return {"commands": commands, "consecutive_ready": count, "last_source_step": measurement.source_semantic_step,
		"outcome": "ready" if count >= limits.ready_consecutive_completed_samples else "timeout" if commands == limits.maximum_commands else "pending"}

static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": "RECOVERY_WALKING_READINESS_"+code}
