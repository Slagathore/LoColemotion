extends RefCounted
# Pure finite schedule over retained native support and measured motion.
const POLICY := "sporespore_balanced_wave_recovery_remaining_support_release_v1"
const ENTRY := "remaining_support_release_joint_bounded_contact_gated_v1"
const STARTUP_POLICY := "sporespore_balanced_wave_recovery_startup_reference_velocity_v1"
const STARTUP_ENTRY := "startup_reference_velocity_joint_bounded_contact_gated_v1"
const MAX_WALK := 1600
const STOP_STEPS := 120
const SETTLED_STEPS := 30
const LIMBS := ["front_left", "front_right", "rear_left", "rear_right"]
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")

static func selected_policy_v1(id: String) -> bool:
	return id in ["r10ap_progressive_headroom_route_v1", "r10am_support_anchored_route_v1", "r10aj_hip_recenter_route_v1", "r10ai_concurrent_load_rise_route_v1", "r10ag_detection_frame_load_seeking_route_v1", POLICY, STARTUP_POLICY, "r10g_v50_finite_cycle_walking_route_v1", "r10h_v50_stance_entry_route_v1", "r10i_v50_flexed_entry_route_v1", "r10j_v50_settled_hold_route_v1", "r10k_v51_partial_fall_recovery_route_v1", "r10l_v52_partial_fall_recovery_route_v1", "r10m_v53_partial_fall_recovery_route_v1", "r10n_v54_partial_fall_recovery_route_v1", "r10o_v55_partial_fall_recovery_route_v1", "r10q_v55_upright_recovery_route_v1", "r10r_v55_upright_recovery_route_v1", "r10s_v56_upright_recovery_route_v1", "r10t_v56_post_recovery_hold_route_v1", "r10u_v56_post_recovery_hold_route_v1", "r10v_v56_post_recovery_hold_route_v1", "r10y_partial_direct_neutral_route_v1", "r10z_partial_pose_geometry_route_v1", "r10aa_partial_load_seeking_route_v1", "r10ab_partial_downward_rise_route_v1"]

static func selected_entry_v1(id: String) -> bool:
	return id in ["r10ap_v56_joint_bounded_contact_gated_v1", "r10am_v56_joint_bounded_contact_gated_v1", "r10aj_v56_joint_bounded_contact_gated_v1", "r10ai_v56_joint_bounded_contact_gated_v1", "r10ag_v56_joint_bounded_contact_gated_v1", ENTRY, STARTUP_ENTRY, "r10g_v50_joint_bounded_contact_gated_v1", "r10g_v50_joint_bounded_contact_gated_v2", "r10g_v50_joint_bounded_contact_gated_v3", "r10h_v50_joint_bounded_contact_gated_v1", "r10i_v50_joint_bounded_contact_gated_v1", "r10j_v50_joint_bounded_contact_gated_v1", "r10k_v51_joint_bounded_contact_gated_v1", "r10l_v52_joint_bounded_contact_gated_v1", "r10m_v53_joint_bounded_contact_gated_v1", "r10n_v54_joint_bounded_contact_gated_v1", "r10o_v55_joint_bounded_contact_gated_v1", "r10q_v55_joint_bounded_contact_gated_v1", "r10r_v55_joint_bounded_contact_gated_v1", "r10s_v56_joint_bounded_contact_gated_v1", "r10t_v56_joint_bounded_contact_gated_v1", "r10u_v56_joint_bounded_contact_gated_v1", "r10v_v56_joint_bounded_contact_gated_v1", "r10y_v56_joint_bounded_contact_gated_v1", "r10z_v56_joint_bounded_contact_gated_v1", "r10aa_v56_joint_bounded_contact_gated_v1", "r10ab_v56_joint_bounded_contact_gated_v1", "r10ac_v56_joint_bounded_contact_gated_v1", "r10ad_v56_joint_bounded_contact_gated_v1", "r10ae_v56_joint_bounded_contact_gated_v1", "r10af_v56_joint_bounded_contact_gated_v1"]

static func retention_schema_v1(policy_id: String) -> String:
	if policy_id == "r10ap_progressive_headroom_route_v1": return "sporespore_r10ap_godot_cycle_stop_retention_v1"
	if policy_id == "r10am_support_anchored_route_v1": return "sporespore_r10am_godot_cycle_stop_retention_v1"
	if policy_id == "r10aj_hip_recenter_route_v1": return "sporespore_r10aj_godot_cycle_stop_retention_v1"
	if policy_id == "r10ai_concurrent_load_rise_route_v1": return "sporespore_r10ai_godot_cycle_stop_retention_v1"
	if policy_id == "r10ag_detection_frame_load_seeking_route_v1": return "sporespore_r10ag_godot_cycle_stop_retention_v1"
	if policy_id == "r10ab_partial_downward_rise_route_v1": return "sporespore_r10ab_godot_cycle_stop_retention_v1"
	if policy_id == "r10aa_partial_load_seeking_route_v1": return "sporespore_r10aa_godot_cycle_stop_retention_v1"
	if policy_id == "r10z_partial_pose_geometry_route_v1": return "sporespore_r10z_godot_cycle_stop_retention_v1"
	if policy_id == "r10y_partial_direct_neutral_route_v1": return "sporespore_r10y_godot_cycle_stop_retention_v1"
	if policy_id == "r10v_v56_post_recovery_hold_route_v1": return "sporespore_r10v_godot_cycle_stop_retention_v1"
	if policy_id == "r10u_v56_post_recovery_hold_route_v1": return "sporespore_r10u_godot_cycle_stop_retention_v1"
	if policy_id == "r10t_v56_post_recovery_hold_route_v1": return "sporespore_r10t_godot_cycle_stop_retention_v1"
	if policy_id == "r10s_v56_upright_recovery_route_v1": return "sporespore_r10s_godot_cycle_stop_retention_v1"
	if policy_id == "r10r_v55_upright_recovery_route_v1": return "sporespore_r10r_godot_cycle_stop_retention_v1"
	if policy_id == "r10q_v55_upright_recovery_route_v1": return "sporespore_r10q_godot_cycle_stop_retention_v1"
	if policy_id == "r10o_v55_partial_fall_recovery_route_v1": return "sporespore_r10o_godot_cycle_stop_retention_v1"
	if policy_id == "r10n_v54_partial_fall_recovery_route_v1": return "sporespore_r10n_godot_cycle_stop_retention_v1"
	if policy_id == "r10m_v53_partial_fall_recovery_route_v1": return "sporespore_r10m_godot_cycle_stop_retention_v1"
	if policy_id == "r10l_v52_partial_fall_recovery_route_v1": return "sporespore_r10l_godot_cycle_stop_retention_v1"
	if policy_id == "r10k_v51_partial_fall_recovery_route_v1": return "sporespore_r10k_godot_cycle_stop_retention_v1"
	if policy_id == "r10j_v50_settled_hold_route_v1": return "sporespore_r10j_godot_cycle_stop_retention_v1"
	if policy_id == "r10i_v50_flexed_entry_route_v1": return "sporespore_r10i_godot_cycle_stop_retention_v1"
	if policy_id == "r10h_v50_stance_entry_route_v1": return "sporespore_r10h_godot_cycle_stop_retention_v1"
	if policy_id == "r10g_v50_finite_cycle_walking_route_v1":
		return "sporespore_r10g_godot_cycle_stop_retention_v1"
	if policy_id == STARTUP_POLICY:
		return "sporespore_v50_godot_cycle_stop_retention_v1"
	return "sporespore_v49_godot_cycle_stop_retention_v1" if policy_id == POLICY else ""

static func initial_v1() -> Dictionary:
	return {"last_command": 0, "released": {}, "absent": {}, "completed": {},
		"cycle_end_command": 0, "stopping_commands": 0, "consecutive_settled_commands": 0}

static func stopping_v1(memory: Dictionary) -> bool:
	return memory.get("cycle_end_command", 0) > 0

static func stop_reason_v1(memory: Dictionary) -> String:
	if memory.get("stopping_commands", 0) == STOP_STEPS:
		return "diagnostic_cycle_aligned_stop_complete"
	if memory.get("last_command", 0) == MAX_WALK and not stopping_v1(memory):
		return "diagnostic_cycle_aligned_walking_limit"
	return ""

static func advance_v1(memory: Dictionary, control: Dictionary, source: Dictionary) -> Dictionary:
	var n: int = int(control.get("session_local_step", -1))
	var global_step: int = int(control.get("commanded_global_step", -1))
	var observation: Dictionary = source.get("observation", {})
	var trace: Dictionary = source.get("precommand_trace", {})
	if n != memory.get("last_command", -1) + 1 or n > MAX_WALK + STOP_STEPS or not stop_reason_v1(memory).is_empty() or observation.get("semantic_step") != global_step or trace.get("global_semantic_step") != global_step:
		return {"ok": false, "failure_code": "V49_CYCLE_SOURCE_CLOCK"}
	var contacts: Array = observation.get("state", {}).get("ordered_contact_observations", [])
	var output: Dictionary = control.get("native_output", {})
	var transfer: Dictionary = output.get("actuation", {}).get("receipt", {}).get("recovery_support_plane", {}).get("measured_support_transfer", {})
	var limbs: Array = output.get("next_memory", {}).get("ordered_limb_memory", [])
	if contacts.size() != 4 or limbs.size() != 4 or transfer.is_empty():
		return {"ok": false, "failure_code": "V49_CYCLE_SOURCE_POPULATION"}
	var phases := {}
	var bearing := {}
	for i in range(4):
		if contacts[i].get("contact_site_id") != LIMBS[i] + "_foot" or typeof(contacts[i].get("presence")) != TYPE_BOOL or typeof(contacts[i].get("bears_support")) != TYPE_BOOL:
			return {"ok": false, "failure_code": "V49_CYCLE_CONTACT_KNOWN"}
		bearing[LIMBS[i]] = contacts[i]["presence"] and contacts[i]["bears_support"]
		phases[limbs[i]["limb_id"]] = posmod(int(limbs[i]["gait_step"]) + 360 - i * 90, 360)
	var next := memory.duplicate(true)
	next["last_command"] = n
	if stopping_v1(memory):
		if n != memory["cycle_end_command"] + memory["stopping_commands"] + 1:
			return {"ok": false, "failure_code": "V49_STOP_CLOCK"}
		next["stopping_commands"] += 1
	else:
		if transfer.get("preparation_released_this_command") == true:
			var planned: String = transfer.get("planned_swing_limb_id", "")
			if planned not in LIMBS:
				return {"ok": false, "failure_code": "V49_CYCLE_RELEASE_LIMB"}
			if not next["released"].has(planned): next["released"][planned] = n
		var all_stance := true
		for limb in LIMBS:
			if not phases.has(limb): return {"ok": false, "failure_code": "V49_CYCLE_PHASE_POPULATION"}
			if next["released"].has(limb) and phases[limb] <= 72 and not bearing[limb] and not next["absent"].has(limb): next["absent"][limb] = n
			if next["absent"].has(limb) and phases[limb] > 72 and bearing[limb] and not next["completed"].has(limb): next["completed"][limb] = n
			all_stance = all_stance and phases[limb] > 72 and bearing[limb]
		if next["completed"].size() == 4 and all_stance: next["cycle_end_command"] = n
	var com: Dictionary = observation.get("center_of_mass", {})
	var velocity: Dictionary = com.get("linear_velocity_world_m_s", {})
	var omega: Dictionary = observation.get("state", {}).get("base_twist_world", {}).get("angular_velocity_rad_s", {})
	var tilt: Variant = trace.get("torso_tilt_rad")
	for vector in [velocity, omega]:
		for key in ["x", "y", "z"]:
			if typeof(vector.get(key)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(vector[key]): return {"ok": false, "failure_code": "V49_STOP_MOTION_UNKNOWN"}
	if com.get("source_measurement") != true or typeof(tilt) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(tilt): return {"ok": false, "failure_code": "V49_STOP_MEASUREMENT_SOURCE"}
	var speed := sqrt(velocity.x * velocity.x + velocity.z * velocity.z)
	var angular := sqrt(omega.x * omega.x + omega.y * omega.y + omega.z * omega.z)
	var settled: bool = not bearing.values().has(false) and speed <= 0.03 and angular <= 0.15 and tilt <= 0.05
	if stopping_v1(memory): next["consecutive_settled_commands"] = next["consecutive_settled_commands"] + 1 if settled else 0
	return {"ok": true, "next_memory": next, "postcommand_settled": settled,
		"postcommand_horizontal_com_speed_m_s": speed, "postcommand_torso_angular_speed_rad_s": angular,
		"postcommand_torso_tilt_rad": tilt, "postcommand_bearing": bearing,
		"new_world_count": 0, "new_solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}
