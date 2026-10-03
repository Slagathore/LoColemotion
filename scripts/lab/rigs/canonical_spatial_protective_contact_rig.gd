class_name LabCanonicalSpatialProtectiveContactRig
extends "res://scripts/lab/rigs/canonical_spatial_stance_rig.gd"
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## BR14A.5 physical protective-contact fixture.
##
## The front-right foot is first cleared using real joint torques. After the
## matched disturbance, active trials drive it to the declared wider floor
## target while controls retain the clear-target command until incidental
## collapse. The other limbs retain the exact stance controller.

const SupportMarginObserverScript := preload(
	"res://scripts/lab/mechanics/spatial_support_margin_observer.gd"
)


func run_protective_contact_trial(
	tree: SceneTree, profile: Dictionary, experiment: Dictionary, seed: int, contact_enabled: bool
) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = ("BR14A_Protective_%d_%s" % [seed, "active" if contact_enabled else "control"])
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var world := Node3D.new()
	world.name = "BR14ACanonicalSpatialProtectiveContactWorld"
	var floor := _build_floor(float(profile["contact_friction_coefficient"]))
	var torso := _build_torso(profile["torso"])
	var body_by_id: Dictionary = {TORSO_ID: torso}
	var limbs: Array = []
	var joint_nodes: Array[Joint3D] = []
	var swing_limb: Dictionary = {}
	for limb_value in profile["limbs"]:
		var limb := _build_limb(limb_value, float(profile["contact_friction_coefficient"]))
		torso.add_collision_exception_with(limb["upper"])
		(limb["upper"] as RigidBody3D).add_collision_exception_with(torso)
		limbs.append(limb)
		body_by_id[String(limb["upper_id"])] = limb["upper"]
		body_by_id[String(limb["lower_id"])] = limb["lower"]
		joint_nodes.append(limb["hip_joint"])
		joint_nodes.append(limb["knee_joint"])
		if String(limb["limb_id"]) == String(experiment["swing_limb_id"]):
			swing_limb = limb
	if swing_limb.is_empty():
		viewport.queue_free()
		return {"ok": false, "failure_code": "SPATIAL_PROTECTIVE_SWING_LIMB_MISSING"}
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
		"br14a_protective_%d_%s" % [seed, "active" if contact_enabled else "control"]
	)
	var trial_ticks := int(experiment["trial_ticks"])
	var weight_shift_start_tick := int(experiment["weight_shift_start_tick"])
	var weight_shift_complete_tick := int(experiment["weight_shift_complete_tick"])
	var lift_start_tick := int(experiment["lift_start_tick"])
	var lift_complete_tick := int(experiment["lift_complete_tick"])
	var disturbance_tick := int(experiment["disturbance_tick"])
	var landing_start_tick := int(experiment["landing_start_tick"])
	var landing_alignment_complete_tick := int(experiment["landing_alignment_complete_tick"])
	var landing_complete_tick := int(experiment["landing_target_complete_tick"])
	var touchdown_deadline_tick := int(experiment["touchdown_deadline_tick"])
	var shift_release_start_tick := int(experiment["weight_shift_release_start_tick"])
	var shift_release_complete_tick := int(experiment["weight_shift_release_complete_tick"])
	var step_s := 1.0 / float(profile["physics_hz"])
	var initial_target := _vector3(experiment["initial_foot_center_world_m"])
	var clear_target := _vector3(experiment["clear_foot_target_world_m"])
	var landing_target := _vector3(experiment["landing_foot_target_world_m"])
	var target_torso_shift := _vector3(experiment["precontact_target_torso_shift_world_m"])
	var lift_origin_world := initial_target
	var disturbance_axis := _vector3(experiment["disturbance_axis_world"]).normalized()
	var fixture_complete := true
	var fixture_failure_code := ""
	var all_receipts_complete := true
	var maximum_pairing_residual_nm := 0.0
	var maximum_applied_torque_nm := 0.0
	var structural_saturation_count := 0
	var active_command_count := 0
	var disturbance_operation_count := 0
	var swing_clear_ticks_before_disturbance := 0
	var swing_contact_seen_after_clear := false
	var first_touch_tick := -1
	var first_touch_target_error_m := INF
	var post_touch_contact_ticks := 0
	var post_touch_samples := 0
	var recovery_dwell_ticks := 0
	var longest_recovery_dwell_ticks := 0
	var maximum_anchor_error_m := 0.0
	var maximum_hinge_axis_error_rad := 0.0
	var maximum_swing_tracking_error_m := 0.0
	var maximum_internal_roll_torque_nm := 0.0
	var support_margin_at_lift_start_m := NAN
	var support_margin_at_disturbance_m := NAN
	var minimum_three_contact_support_margin_m := INF
	var support_margin_observations_complete := true
	var support_contact_ticks: Dictionary = {}
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		if String(limb["limb_id"]) != String(experiment["swing_limb_id"]):
			support_contact_ticks[String(limb["contact_id"])] = 0
	var previous_swing_contact := _foot_shape_contacts_floor(swing_limb)
	var support_relative_world_by_limb: Dictionary = {}
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		if String(limb["limb_id"]) != String(experiment["swing_limb_id"]):
			support_relative_world_by_limb[String(limb["limb_id"])] = (
				_foot_center_world(limb) - torso.global_position
			)
	for tick in range(trial_ticks):
		var ordered_support_points: Array[Vector3] = []
		for limb_value in limbs:
			var support_limb: Dictionary = limb_value
			if String(support_limb["limb_id"]) != String(experiment["swing_limb_id"]):
				ordered_support_points.append(_foot_center_world(support_limb))
		var support_margin_result := SupportMarginObserverScript.observe(
			body_by_id, ordered_support_points
		)
		if not bool(support_margin_result.get("ok", false)):
			support_margin_observations_complete = false
			fixture_complete = false
			fixture_failure_code = String(
				support_margin_result.get(
					"failure_code", "SPATIAL_PROTECTIVE_SUPPORT_MARGIN_OBSERVATION_FAILED"
				)
			)
			break
		var current_support_margin_m := float(support_margin_result["minimum_signed_margin_m"])
		if tick == lift_start_tick:
			support_margin_at_lift_start_m = current_support_margin_m
		if tick == disturbance_tick:
			support_margin_at_disturbance_m = current_support_margin_m
		if tick >= lift_start_tick and first_touch_tick < 0:
			minimum_three_contact_support_margin_m = minf(
				minimum_three_contact_support_margin_m, current_support_margin_m
			)
		for limb_value in limbs:
			var geometry := _joint_geometry_diagnostics(torso, limb_value)
			maximum_anchor_error_m = maxf(
				maximum_anchor_error_m, float(geometry["maximum_anchor_error_m"])
			)
			maximum_hinge_axis_error_rad = maxf(
				maximum_hinge_axis_error_rad, float(geometry["maximum_axis_error_rad"])
			)
		var target := initial_target
		var swing_active := tick >= lift_start_tick
		if tick == lift_start_tick:
			lift_origin_world = _foot_center_world(swing_limb)
		if tick >= lift_start_tick and tick < lift_complete_tick:
			target = lift_origin_world.lerp(
				clear_target,
				_smoothstep(
					float(tick - lift_start_tick) / float(lift_complete_tick - lift_start_tick)
				)
			)
		elif tick >= lift_complete_tick:
			target = clear_target
		if contact_enabled and tick >= landing_start_tick:
			var aligned_target := Vector3(landing_target.x, clear_target.y, landing_target.z)
			if tick < landing_alignment_complete_tick:
				target = clear_target.lerp(
					aligned_target,
					_smoothstep(
						(
							float(tick - landing_start_tick)
							/ float(landing_alignment_complete_tick - landing_start_tick)
						)
					)
				)
			else:
				target = aligned_target.lerp(
					landing_target,
					_smoothstep(
						clampf(
							(
								float(tick - landing_alignment_complete_tick)
								/ float(landing_complete_tick - landing_alignment_complete_tick)
							),
							0.0,
							1.0
						)
					)
				)
		var swing_torque_overrides: Dictionary = {}
		if swing_active:
			maximum_swing_tracking_error_m = maxf(
				maximum_swing_tracking_error_m, _foot_center_world(swing_limb).distance_to(target)
			)
			var servo_result := _task_space_joint_torques(
				swing_limb,
				torso,
				target,
				Vector3.ZERO,
				float(experiment["swing_task_position_gain_n_per_m"]),
				float(experiment["swing_task_velocity_gain_ns_per_m"]),
				float(experiment["maximum_swing_task_force_n"])
			)
			if not bool(servo_result.get("ok", false)):
				fixture_complete = false
				fixture_failure_code = String(
					servo_result.get("failure_code", "SPATIAL_PROTECTIVE_COORDINATE_SERVO_FAILED")
				)
				break
			swing_torque_overrides = servo_result["joint_torque_overrides"]
			if contact_enabled and first_touch_tick >= 0:
				swing_torque_overrides.erase("%s.knee_pitch" % String(experiment["swing_limb_id"]))
		var shift_fraction := 0.0
		if tick >= weight_shift_start_tick and tick < weight_shift_complete_tick:
			shift_fraction = _smoothstep(
				(
					float(tick - weight_shift_start_tick)
					/ float(weight_shift_complete_tick - weight_shift_start_tick)
				)
			)
		elif tick >= weight_shift_complete_tick and tick < shift_release_start_tick:
			shift_fraction = 1.0
		elif tick >= shift_release_start_tick and tick < shift_release_complete_tick:
			shift_fraction = (
				1.0
				- _smoothstep(
					(
						float(tick - shift_release_start_tick)
						/ float(shift_release_complete_tick - shift_release_start_tick)
					)
				)
			)
		var desired_torso_shift := target_torso_shift * shift_fraction
		var desired_roll := 0.0
		if tick >= weight_shift_start_tick and tick < weight_shift_complete_tick:
			desired_roll = (
				float(experiment["precontact_target_roll_rad"])
				* _smoothstep(
					(
						float(tick - weight_shift_start_tick)
						/ float(weight_shift_complete_tick - weight_shift_start_tick)
					)
				)
			)
		elif tick >= weight_shift_complete_tick and tick < shift_release_start_tick:
			desired_roll = float(experiment["precontact_target_roll_rad"])
		elif tick >= shift_release_start_tick and tick < shift_release_complete_tick:
			desired_roll = (
				float(experiment["precontact_target_roll_rad"])
				* (
					1.0
					- _smoothstep(
						(
							float(tick - shift_release_start_tick)
							/ float(shift_release_complete_tick - shift_release_start_tick)
						)
					)
				)
			)
		var torso_roll := _signed_roll_rad(torso)
		var internal_roll_torque := clampf(
			(
				float(experiment["roll_position_gain_nm_per_rad"]) * (desired_roll - torso_roll)
				- (
					float(experiment["roll_velocity_gain_nm_s_per_rad"])
					* torso.angular_velocity.dot(Vector3.RIGHT)
				)
			),
			-float(experiment["maximum_internal_roll_torque_nm"]),
			float(experiment["maximum_internal_roll_torque_nm"])
		)
		maximum_internal_roll_torque_nm = maxf(
			maximum_internal_roll_torque_nm, absf(internal_roll_torque)
		)
		var roll_additions := _roll_torque_additions(limbs, torso, internal_roll_torque)
		for limb_value in limbs:
			var support_limb: Dictionary = limb_value
			var support_limb_id := String(support_limb["limb_id"])
			if support_limb_id == String(experiment["swing_limb_id"]):
				continue
			var support_target := (
				torso.global_position
				+ (support_relative_world_by_limb[support_limb_id] as Vector3)
				- desired_torso_shift
			)
			var support_result := _task_space_joint_torques(
				support_limb,
				torso,
				support_target,
				torso.linear_velocity,
				float(experiment["support_shift_task_position_gain_n_per_m"]),
				float(experiment["support_shift_task_velocity_gain_ns_per_m"]),
				float(experiment["maximum_support_shift_task_force_n"])
			)
			_merge_torque_additions(roll_additions, support_result["joint_torque_overrides"])
		var command_result := _command_tick(
			tick,
			limbs,
			body_by_id,
			profile,
			experiment,
			receipt_sink,
			true,
			step_s,
			true,
			swing_torque_overrides,
			roll_additions
		)
		if not bool(command_result.get("ok", false)):
			fixture_complete = false
			fixture_failure_code = String(
				command_result.get("failure_code", "SPATIAL_PROTECTIVE_COMMAND_FAILED")
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
			torso.apply_torque_impulse(
				disturbance_axis * float(experiment["disturbance_torque_impulse_nms"])
			)
			disturbance_operation_count += 1
		await tree.physics_frame
		var swing_foot_position := _foot_center_world(swing_limb)
		var swing_contact := _foot_shape_contacts_floor(swing_limb)
		if contact_enabled and tick in [240, 320, 340, 400, 460, 480, 490, 510, 530, 650, 800, 959]:
			print(
				(
					(
						"    tick=%d target=%s foot=%s contact=%s torso_h=%.6f "
						+ "tilt=%.6f roll=%.6f anchor=%.6f hinge=%.6f"
					)
					% [
						tick,
						target,
						swing_foot_position,
						str(swing_contact),
						torso.global_position.y,
						_tilt(torso),
						_signed_roll_rad(torso),
						maximum_anchor_error_m,
						maximum_hinge_axis_error_rad,
					]
				)
			)
		if (
			tick >= lift_complete_tick
			and tick < disturbance_tick
			and not swing_contact
			and swing_foot_position.y >= float(experiment["minimum_clear_height_m"])
		):
			swing_clear_ticks_before_disturbance += 1
		if tick >= lift_complete_tick and not swing_contact:
			swing_contact_seen_after_clear = true
		if (
			tick >= landing_start_tick
			and first_touch_tick < 0
			and swing_contact_seen_after_clear
			and swing_contact
			and not previous_swing_contact
		):
			first_touch_tick = tick
			first_touch_target_error_m = swing_foot_position.distance_to(landing_target)
		if first_touch_tick >= 0 and tick >= first_touch_tick:
			post_touch_samples += 1
			if swing_contact:
				post_touch_contact_ticks += 1
		for limb_value in limbs:
			var limb: Dictionary = limb_value
			if String(limb["limb_id"]) == String(experiment["swing_limb_id"]):
				continue
			if _foot_shape_contacts_floor(limb):
				var contact_id := String(limb["contact_id"])
				support_contact_ticks[contact_id] = int(support_contact_ticks[contact_id]) + 1
		var all_four_contacts := _all_feet_bearing(floor, limbs)
		var recovered := (
			first_touch_tick >= 0
			and all_four_contacts
			and not (floor in torso.get_colliding_bodies())
			and (
				absf(torso.global_position.y - float(profile["torso"]["center_world_m"][1]))
				<= float(experiment["recovery_height_error_limit_m"])
			)
			and _tilt(torso) <= float(experiment["recovery_tilt_limit_rad"])
			and (
				torso.angular_velocity.length()
				<= float(experiment["recovery_full_speed_limit_rad_s"])
			)
		)
		if recovered:
			recovery_dwell_ticks += 1
			longest_recovery_dwell_ticks = maxi(longest_recovery_dwell_ticks, recovery_dwell_ticks)
		else:
			recovery_dwell_ticks = 0
		previous_swing_contact = swing_contact

	var support_contact_fractions: Dictionary = {}
	for contact_id in support_contact_ticks:
		support_contact_fractions[contact_id] = (
			float(support_contact_ticks[contact_id]) / float(trial_ticks)
		)
	var summary := {
		"schema_version": "canonical_spatial_protective_contact_candidate_summary_v1",
		"profile_id": profile["profile_id"],
		"profile_sha256": profile["profile_sha256"],
		"experiment_id": experiment["experiment_id"],
		"experiment_sha256": experiment["experiment_sha256"],
		"candidate_result": experiment["candidate_result"],
		"behavior_state": experiment["behavior_state"],
		"seed": seed,
		"contact_enabled": contact_enabled,
		"fixture_complete": fixture_complete,
		"fixture_failure_code": fixture_failure_code,
		"trial_ticks": trial_ticks,
		"disturbance_tick": disturbance_tick,
		"touchdown_deadline_tick": touchdown_deadline_tick,
		"disturbance_operation_count": disturbance_operation_count,
		"disturbance_is_controller_operation": false,
		"swing_limb_id": experiment["swing_limb_id"],
		"swing_contact_id": experiment["swing_contact_id"],
		"swing_clear_ticks_before_disturbance": swing_clear_ticks_before_disturbance,
		"first_touch_tick": maxi(first_touch_tick, 0),
		"touchdown_before_deadline":
		first_touch_tick >= 0 and first_touch_tick <= touchdown_deadline_tick,
		"first_touch_target_error_m": first_touch_target_error_m,
		"post_touch_contact_fraction":
		float(post_touch_contact_ticks) / float(maxi(post_touch_samples, 1)),
		"support_contact_fractions": support_contact_fractions,
		"longest_recovery_dwell_ticks": longest_recovery_dwell_ticks,
		"recovery_dwell_observed":
		longest_recovery_dwell_ticks >= int(experiment["recovery_dwell_ticks_required"]),
		"final_swing_foot_center_world_m": _foot_center_world(swing_limb),
		"final_torso_height_m": torso.global_position.y,
		"final_height_error_m":
		absf(torso.global_position.y - float(profile["torso"]["center_world_m"][1])),
		"final_tilt_rad": _tilt(torso),
		"final_full_speed_rad_s": torso.angular_velocity.length(),
		"maximum_swing_tracking_error_m": maximum_swing_tracking_error_m,
		"maximum_internal_roll_torque_nm": maximum_internal_roll_torque_nm,
		"support_margin_observations_complete": support_margin_observations_complete,
		"support_margin_at_lift_start_m": support_margin_at_lift_start_m,
		"support_margin_at_disturbance_m": support_margin_at_disturbance_m,
		"minimum_three_contact_support_margin_m": minimum_three_contact_support_margin_m,
		"support_margin_is_load_allocation": false,
		"body_count": body_by_id.size(),
		"physical_limb_count": limbs.size(),
		"actuated_dof_count": 12,
		"joint_node_count": joint_nodes.size(),
		"static_body_count": 1,
		"ordinary_preexisting_contact_count": 3,
		"new_contact_creation_count": 1 if first_touch_tick >= 0 else 0,
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
		"per_contact_commands_are_measurements": false,
		"per_foot_measured_load_allocation_available": false,
		"contact_presence_is_bearing_measurement": false,
		"new_protective_contact_established": false,
		"locomotor_step_established": false,
		"free_3d_recovery_established": false,
		"step_gait_or_walking_established": false,
		"automatic_creature_guidance_allowed": false,
	}
	viewport.queue_free()
	await tree.physics_frame
	await tree.process_frame
	return {"ok": fixture_complete, "summary": summary}


static func _task_space_joint_torques(
	limb: Dictionary,
	torso: RigidBody3D,
	target: Vector3,
	target_velocity: Vector3,
	position_gain_n_per_m: float,
	velocity_gain_ns_per_m: float,
	maximum_force_n: float
) -> Dictionary:
	var upper: RigidBody3D = limb["upper"]
	var lower: RigidBody3D = limb["lower"]
	var foot := _foot_center_world(limb)
	var foot_relative_to_lower := foot - lower.global_position
	var foot_velocity := (
		lower.linear_velocity + lower.angular_velocity.cross(foot_relative_to_lower)
	)
	var task_force := (
		position_gain_n_per_m * (target - foot)
		- velocity_gain_ns_per_m * (foot_velocity - target_velocity)
	)
	if task_force.length() > maximum_force_n:
		task_force *= maximum_force_n / task_force.length()
	var overrides: Dictionary = {}
	for state_value in limb["joint_states"]:
		var state: Dictionary = state_value
		var role := String(state["role"])
		var parent: RigidBody3D = torso
		if role == "knee_pitch":
			parent = upper
		var axis_world := (parent.global_basis * _vector3(state["axis_parent_local"])).normalized()
		var pivot := parent.to_global(state["anchor_parent_local"])
		var linear_jacobian_column := axis_world.cross(foot - pivot)
		overrides[String(state["joint_id"])] = linear_jacobian_column.dot(task_force)
	return {
		"ok": true,
		"joint_torque_overrides": overrides,
	}


static func _merge_torque_additions(target: Dictionary, source: Dictionary) -> void:
	for joint_id in source:
		target[String(joint_id)] = (
			float(target.get(String(joint_id), 0.0)) + float(source[joint_id])
		)


static func _roll_torque_additions(
	limbs: Array, torso: RigidBody3D, desired_torso_torque_nm: float
) -> Dictionary:
	var additions: Dictionary = {}
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		for state_value in limb["joint_states"]:
			var state: Dictionary = state_value
			if String(state["role"]) != "hip_abduction":
				continue
			var axis := (torso.global_basis * _vector3(state["axis_parent_local"])).normalized()
			var projection := axis.dot(Vector3.RIGHT)
			if absf(projection) > 1.0e-6:
				additions[String(state["joint_id"])] = (
					-desired_torso_torque_nm / (4.0 * projection)
				)
	return additions


static func _signed_roll_rad(torso: RigidBody3D) -> float:
	var up := torso.global_basis.y.normalized()
	return atan2(up.z, up.y)


static func _foot_center_world(limb: Dictionary) -> Vector3:
	var lower: RigidBody3D = limb["lower"]
	return lower.to_global(Vector3(float(limb["configuration"]["lower_length_m"]) * 0.5, 0.0, 0.0))


static func _all_feet_bearing(_floor: StaticBody3D, limbs: Array) -> bool:
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		if not _foot_shape_contacts_floor(limb):
			return false
	return true


static func _foot_shape_contacts_floor(limb: Dictionary) -> bool:
	var lower: RigidBody3D = limb["lower"]
	return bool(lower.call("has_semantic_contact", "%s_foot" % String(limb["lower_id"]), FLOOR_ID))


static func _smoothstep(value: float) -> float:
	var bounded := clampf(value, 0.0, 1.0)
	return bounded * bounded * (3.0 - 2.0 * bounded)
