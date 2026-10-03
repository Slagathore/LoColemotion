class_name LabCanonicalSpatialArrestRig
extends "res://scripts/lab/rigs/canonical_spatial_stance_rig.gd"
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## BR14A.4 existing-contact roll-disturbance fixture.
##
## Both worlds establish the same active stance before the same torso torque
## impulse. The active world retains relative-pose feedback; the causal
## control retains only the identical static feedforward terms. No foot target
## changes and no new contact body exists.


func run_arrest_trial(
	tree: SceneTree, profile: Dictionary, experiment: Dictionary, seed: int, arrest_enabled: bool
) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "BR14A_Arrest_%d_%s" % [seed, "active" if arrest_enabled else "control"]
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var world := Node3D.new()
	world.name = "BR14ACanonicalSpatialArrestWorld"
	var floor := _build_floor(float(profile["contact_friction_coefficient"]))
	var torso := _build_torso(profile["torso"])
	var body_by_id: Dictionary = {TORSO_ID: torso}
	var limbs: Array = []
	var joint_nodes: Array[Joint3D] = []
	for limb_value in profile["limbs"]:
		var limb := _build_limb(limb_value, float(profile["contact_friction_coefficient"]))
		torso.add_collision_exception_with(limb["upper"])
		(limb["upper"] as RigidBody3D).add_collision_exception_with(torso)
		limbs.append(limb)
		body_by_id[String(limb["upper_id"])] = limb["upper"]
		body_by_id[String(limb["lower_id"])] = limb["lower"]
		joint_nodes.append(limb["hip_joint"])
		joint_nodes.append(limb["knee_joint"])
	for node in [torso, floor]:
		world.add_child(node)
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		for node in [
			limb["upper"],
			limb["lower"],
			limb["hip_joint"],
			limb["knee_joint"],
		]:
			world.add_child(node)
	viewport.add_child(world)
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var hip: Generic6DOFJoint3D = limb["hip_joint"]
		var knee: HingeJoint3D = limb["knee_joint"]
		hip.node_a = hip.get_path_to(torso)
		hip.node_b = hip.get_path_to(limb["upper"])
		knee.node_a = knee.get_path_to(limb["upper"])
		knee.node_b = knee.get_path_to(limb["lower"])
	await tree.process_frame
	await tree.physics_frame
	_capture_rest_state(torso, limbs)
	for body_value in body_by_id.values():
		var body: RigidBody3D = body_value
		body.freeze = false
		body.sleeping = false
	var seed_perturbation := float((seed % 3) - 1) * 0.008
	torso.angular_velocity = Vector3(seed_perturbation, 0.0, -0.5 * seed_perturbation)
	await tree.physics_frame

	var receipt_sink = ReceiptSinkScript.new(
		"br14a_arrest_%d_%s" % [seed, "active" if arrest_enabled else "control"]
	)
	var trial_ticks := int(experiment["trial_ticks"])
	var disturbance_tick := int(experiment["disturbance_tick"])
	var step_s := 1.0 / float(profile["physics_hz"])
	var disturbance_axis := _vector3(experiment["disturbance_axis_world"]).normalized()
	var disturbance_impulse := (
		disturbance_axis * float(experiment["disturbance_torque_impulse_nms"])
	)
	var fixture_complete := true
	var fixture_failure_code := ""
	var all_receipts_complete := true
	var maximum_pairing_residual_nm := 0.0
	var maximum_applied_torque_nm := 0.0
	var structural_saturation_count := 0
	var active_command_count := 0
	var disturbance_operation_count := 0
	var pre_disturbance_all_feet_bearing := false
	var pre_disturbance_height_error_m := INF
	var pre_disturbance_tilt_rad := INF
	var pre_disturbance_axis_speed_rad_s := INF
	var post_contact_ticks: Dictionary = {}
	for limb_value in limbs:
		post_contact_ticks[String((limb_value as Dictionary)["contact_id"])] = 0
	var post_sample_count := 0
	var post_axis_speed_area_rad := 0.0
	var peak_post_axis_speed_rad_s := 0.0
	var peak_post_full_speed_rad_s := 0.0
	var maximum_post_tilt_rad := 0.0
	var recovery_dwell_ticks := 0
	var longest_recovery_dwell_ticks := 0
	var recovery_completion_ticks := -1
	var maximum_anchor_error_m := 0.0
	var maximum_hinge_axis_error_rad := 0.0
	var torso_contact_ticks := 0
	for tick in range(trial_ticks):
		var all_feet_bearing := _all_feet_bearing(floor, limbs)
		if floor in torso.get_colliding_bodies():
			torso_contact_ticks += 1
		for limb_value in limbs:
			var geometry := _joint_geometry_diagnostics(torso, limb_value)
			maximum_anchor_error_m = maxf(
				maximum_anchor_error_m, float(geometry["maximum_anchor_error_m"])
			)
			maximum_hinge_axis_error_rad = maxf(
				maximum_hinge_axis_error_rad, float(geometry["maximum_axis_error_rad"])
			)
		if tick == disturbance_tick:
			pre_disturbance_all_feet_bearing = all_feet_bearing
			pre_disturbance_height_error_m = absf(
				torso.global_position.y - float(profile["torso"]["center_world_m"][1])
			)
			pre_disturbance_tilt_rad = _tilt(torso)
			pre_disturbance_axis_speed_rad_s = absf(torso.angular_velocity.dot(disturbance_axis))
		var feedback_enabled := arrest_enabled or tick <= disturbance_tick
		var command_result := _command_tick(
			tick,
			limbs,
			body_by_id,
			profile,
			experiment,
			receipt_sink,
			true,
			step_s,
			feedback_enabled
		)
		if not bool(command_result.get("ok", false)):
			fixture_complete = false
			fixture_failure_code = String(
				command_result.get("failure_code", "SPATIAL_ARREST_COMMAND_FAILED")
			)
			break
		all_receipts_complete = (
			all_receipts_complete and bool(command_result["receipts_complete"])
		)
		maximum_pairing_residual_nm = maxf(
			maximum_pairing_residual_nm, float(command_result["maximum_pairing_residual_nm"])
		)
		maximum_applied_torque_nm = maxf(
			maximum_applied_torque_nm, float(command_result["maximum_applied_torque_nm"])
		)
		structural_saturation_count += int(command_result["structural_saturation_count"])
		active_command_count += int(command_result["active_command_count"])
		if tick == disturbance_tick:
			torso.apply_torque_impulse(disturbance_impulse)
			disturbance_operation_count += 1
		await tree.physics_frame
		if tick >= disturbance_tick:
			post_sample_count += 1
			var post_all_feet_bearing := true
			for limb_value in limbs:
				var limb: Dictionary = limb_value
				var bearing := floor in (limb["lower"] as RigidBody3D).get_colliding_bodies()
				post_all_feet_bearing = post_all_feet_bearing and bearing
				if bearing:
					var contact_id := String(limb["contact_id"])
					post_contact_ticks[contact_id] = int(post_contact_ticks[contact_id]) + 1
			var axis_speed := absf(torso.angular_velocity.dot(disturbance_axis))
			var full_speed := torso.angular_velocity.length()
			var tilt := _tilt(torso)
			var height_error := absf(
				torso.global_position.y - float(profile["torso"]["center_world_m"][1])
			)
			post_axis_speed_area_rad += axis_speed * step_s
			peak_post_axis_speed_rad_s = maxf(peak_post_axis_speed_rad_s, axis_speed)
			peak_post_full_speed_rad_s = maxf(peak_post_full_speed_rad_s, full_speed)
			maximum_post_tilt_rad = maxf(maximum_post_tilt_rad, tilt)
			var recovered := (
				post_all_feet_bearing
				and not (floor in torso.get_colliding_bodies())
				and height_error <= float(experiment["recovery_height_error_limit_m"])
				and tilt <= float(experiment["recovery_tilt_limit_rad"])
				and axis_speed <= float(experiment["recovery_axis_speed_limit_rad_s"])
				and full_speed <= float(experiment["recovery_full_speed_limit_rad_s"])
			)
			if recovered:
				recovery_dwell_ticks += 1
				longest_recovery_dwell_ticks = maxi(
					longest_recovery_dwell_ticks, recovery_dwell_ticks
				)
				if (
					recovery_completion_ticks < 0
					and recovery_dwell_ticks >= int(experiment["recovery_dwell_ticks_required"])
				):
					recovery_completion_ticks = tick - disturbance_tick + 1
			else:
				recovery_dwell_ticks = 0

	var final_height_error_m := absf(
		torso.global_position.y - float(profile["torso"]["center_world_m"][1])
	)
	var final_axis_speed_rad_s := absf(torso.angular_velocity.dot(disturbance_axis))
	var final_full_speed_rad_s := torso.angular_velocity.length()
	var post_contact_fractions: Dictionary = {}
	for contact_id in post_contact_ticks:
		post_contact_fractions[contact_id] = (
			float(post_contact_ticks[contact_id]) / float(maxi(post_sample_count, 1))
		)
	var summary := {
		"schema_version": "canonical_spatial_arrest_summary_v1",
		"profile_id": profile["profile_id"],
		"profile_sha256": profile["profile_sha256"],
		"experiment_id": experiment["experiment_id"],
		"experiment_sha256": experiment["experiment_sha256"],
		"behavior_state": experiment["behavior_state"],
		"seed": seed,
		"arrest_enabled": arrest_enabled,
		"fixture_complete": fixture_complete,
		"fixture_failure_code": fixture_failure_code,
		"trial_ticks": trial_ticks,
		"disturbance_tick": disturbance_tick,
		"disturbance_axis_world": disturbance_axis,
		"disturbance_torque_impulse_nms": experiment["disturbance_torque_impulse_nms"],
		"disturbance_operation_count": disturbance_operation_count,
		"disturbance_is_controller_operation": false,
		"pre_disturbance_all_feet_bearing": pre_disturbance_all_feet_bearing,
		"pre_disturbance_height_error_m": pre_disturbance_height_error_m,
		"pre_disturbance_tilt_rad": pre_disturbance_tilt_rad,
		"pre_disturbance_axis_speed_rad_s": pre_disturbance_axis_speed_rad_s,
		"post_disturbance_sample_count": post_sample_count,
		"post_contact_fractions": post_contact_fractions,
		"post_axis_speed_area_rad": post_axis_speed_area_rad,
		"peak_post_axis_speed_rad_s": peak_post_axis_speed_rad_s,
		"peak_post_full_speed_rad_s": peak_post_full_speed_rad_s,
		"maximum_post_tilt_rad": maximum_post_tilt_rad,
		"longest_recovery_dwell_ticks": longest_recovery_dwell_ticks,
		"recovery_completion_ticks": maxi(recovery_completion_ticks, 0),
		"recovery_dwell_observed": recovery_completion_ticks >= 0,
		"final_torso_height_m": torso.global_position.y,
		"final_height_error_m": final_height_error_m,
		"final_tilt_rad": _tilt(torso),
		"final_axis_speed_rad_s": final_axis_speed_rad_s,
		"final_full_speed_rad_s": final_full_speed_rad_s,
		"body_count": body_by_id.size(),
		"physical_limb_count": limbs.size(),
		"actuated_dof_count": 12,
		"joint_node_count": joint_nodes.size(),
		"static_body_count": 1,
		"ordinary_existing_contact_count": 4,
		"new_contact_creation_count": 0,
		"world_anchor_count": 0,
		"root_pin_count": 0,
		"rail_count": 0,
		"guide_count": 0,
		"gimbal_count": 0,
		"built_in_joint_motor_count": 0,
		"joint_spring_count": 0,
		"freeze_operation_count_after_release": 0,
		"root_controller_force_or_torque_operation_count": 0,
		"foot_pin_operation_count": 0,
		"pose_teleport_operation_count": 0,
		"active_command_count": active_command_count,
		"all_receipts_complete": all_receipts_complete,
		"maximum_pairing_residual_nm": maximum_pairing_residual_nm,
		"maximum_applied_torque_nm": maximum_applied_torque_nm,
		"structural_saturation_count": structural_saturation_count,
		"maximum_anchor_error_m": maximum_anchor_error_m,
		"maximum_hinge_axis_error_rad": maximum_hinge_axis_error_rad,
		"torso_contact_ticks": torso_contact_ticks,
		"per_contact_commands_are_measurements": false,
		"per_foot_measured_load_allocation_available": false,
		"existing_contact_spatial_arrest_established": false,
		"new_contact_bracing_established": false,
		"free_3d_recovery_established": false,
		"step_gait_or_walking_established": false,
		"automatic_creature_guidance_allowed": false,
	}
	viewport.queue_free()
	await tree.physics_frame
	await tree.process_frame
	return {"ok": fixture_complete, "summary": summary}


static func _all_feet_bearing(floor: StaticBody3D, limbs: Array) -> bool:
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		if floor not in (limb["lower"] as RigidBody3D).get_colliding_bodies():
			return false
	return true
