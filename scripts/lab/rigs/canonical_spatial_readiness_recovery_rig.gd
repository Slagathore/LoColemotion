class_name LabCanonicalSpatialReadinessRecoveryRig
extends "res://scripts/lab/rigs/canonical_spatial_centroidal_contact_rig.gd"
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## BR14A.4R four-contact global-readiness cycle fixture.
##
## No foot target changes and no contact is removed. The active and control
## worlds share the same first handoff acquisition and readiness-loss cycle.
## Only the active world receives the second handoff target.

const ReadinessObserverScript := preload(
	"res://scripts/lab/mechanics/spatial_dynamic_support_observer.gd"
)


func run_readiness_recovery_trial(
	tree: SceneTree,
	profile: Dictionary,
	experiment: Dictionary,
	seed: int,
	second_reacquisition_enabled: bool
) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = (
		"BR14A_ReadinessRecovery_%d_%s"
		% [seed, "active" if second_reacquisition_enabled else "control"]
	)
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var world := Node3D.new()
	world.name = "BR14ACanonicalSpatialReadinessRecoveryWorld"
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
		(
			"br14a_readiness_recovery_%d_%s"
			% [seed, "active" if second_reacquisition_enabled else "control"]
		)
	)
	var trial_ticks := int(experiment["trial_ticks"])
	var step_s := 1.0 / float(profile["physics_hz"])
	var excluded_limb_id := String(experiment["excluded_handoff_limb_id"])
	var initial_support_points := _support_points_world(limbs, excluded_limb_id, false)
	var initial_state := ReadinessObserverScript.observe(
		body_by_id, initial_support_points, float(profile["gravity_m_s2"])
	)
	if not bool(initial_state.get("ok", false)):
		viewport.queue_free()
		return initial_state
	var initial_center_of_mass: Vector3 = initial_state["center_of_mass_world_m"]
	var initial_roll_rad := _signed_roll_rad(torso)
	var initial_pitch_rad := _signed_pitch_rad(torso)
	var initial_incenter := _triangle_incenter_world(initial_support_points)
	var fixed_ready_target := Vector3(
		initial_incenter.x, initial_center_of_mass.y, initial_incenter.z
	)
	var support_relative_world_by_limb: Dictionary = {}
	for limb_value in limbs:
		var support_limb: Dictionary = limb_value
		support_relative_world_by_limb[String(support_limb["limb_id"])] = (
			_foot_center_world(support_limb) - torso.global_position
		)

	var fixture_complete := true
	var fixture_failure_code := ""
	var executed_ticks := 0
	var all_receipts_complete := true
	var maximum_pairing_residual_nm := 0.0
	var maximum_applied_torque_nm := 0.0
	var structural_saturation_count := 0
	var actuator_saturation_count := 0
	var active_command_count := 0
	var support_controller_command_count := 0
	var maximum_commanded_support_endpoint_force_n := 0.0
	var maximum_anchor_error_m := 0.0
	var maximum_hinge_axis_error_rad := 0.0
	var maximum_height_error_m := 0.0
	var maximum_tilt_rad := 0.0
	var maximum_linear_speed_m_s := 0.0
	var maximum_angular_speed_rad_s := 0.0
	var torso_contact_ticks := 0
	var contact_ticks: Dictionary = {}
	for limb_value in limbs:
		contact_ticks[String((limb_value as Dictionary)["contact_id"])] = 0
	var first_ready_dwell_ticks := 0
	var longest_first_ready_dwell_ticks := 0
	var first_readiness_acquired := false
	var readiness_loss_dwell_ticks := 0
	var longest_readiness_loss_dwell_ticks := 0
	var readiness_loss_established := false
	var second_ready_dwell_ticks := 0
	var longest_second_ready_dwell_ticks := 0
	var second_readiness_reacquired := false
	var minimum_first_ready_margin_m := INF
	var maximum_loss_margin_m := -INF
	var minimum_second_ready_margin_m := INF
	var final_com_margin_m := NAN
	var final_capture_margin_m := NAN
	var target_center_of_mass := initial_center_of_mass

	for tick in range(trial_ticks):
		var support_points := _support_points_world(limbs, excluded_limb_id, false)
		var readiness_state := ReadinessObserverScript.observe(
			body_by_id, support_points, float(profile["gravity_m_s2"])
		)
		if not bool(readiness_state.get("ok", false)):
			fixture_complete = false
			fixture_failure_code = String(
				readiness_state.get("failure_code", "SPATIAL_READINESS_RECOVERY_OBSERVATION_FAILED")
			)
			break
		var center_of_mass: Vector3 = readiness_state["center_of_mass_world_m"]
		var center_of_mass_velocity: Vector3 = readiness_state["center_of_mass_velocity_world_m_s"]
		var com_margin_m := float(readiness_state["center_of_mass_margin_m"])
		var capture_margin_m := float(readiness_state["linearized_capture_margin_m"])
		var readiness_margin_m := minf(com_margin_m, capture_margin_m)
		target_center_of_mass = _phase_target(
			tick,
			experiment,
			initial_center_of_mass,
			fixed_ready_target,
			second_reacquisition_enabled
		)

		if (
			tick >= int(experiment["first_acquisition_complete_tick"])
			and tick < int(experiment["first_ready_window_end_tick"])
		):
			minimum_first_ready_margin_m = minf(minimum_first_ready_margin_m, readiness_margin_m)
			if readiness_margin_m >= float(experiment["minimum_ready_margin_m"]):
				first_ready_dwell_ticks += 1
				longest_first_ready_dwell_ticks = maxi(
					longest_first_ready_dwell_ticks, first_ready_dwell_ticks
				)
				if first_ready_dwell_ticks >= int(experiment["readiness_dwell_ticks_required"]):
					first_readiness_acquired = true
			else:
				first_ready_dwell_ticks = 0
		if (
			tick >= int(experiment["readiness_loss_complete_tick"])
			and tick < int(experiment["readiness_loss_window_end_tick"])
		):
			maximum_loss_margin_m = maxf(maximum_loss_margin_m, readiness_margin_m)
			if readiness_margin_m <= float(experiment["maximum_loss_margin_m"]):
				readiness_loss_dwell_ticks += 1
				longest_readiness_loss_dwell_ticks = maxi(
					longest_readiness_loss_dwell_ticks, readiness_loss_dwell_ticks
				)
				if (
					readiness_loss_dwell_ticks
					>= int(experiment["readiness_loss_dwell_ticks_required"])
				):
					readiness_loss_established = true
			else:
				readiness_loss_dwell_ticks = 0
		if tick >= int(experiment["second_acquisition_complete_tick"]):
			minimum_second_ready_margin_m = minf(minimum_second_ready_margin_m, readiness_margin_m)
			if readiness_margin_m >= float(experiment["minimum_ready_margin_m"]):
				second_ready_dwell_ticks += 1
				longest_second_ready_dwell_ticks = maxi(
					longest_second_ready_dwell_ticks, second_ready_dwell_ticks
				)
				if second_ready_dwell_ticks >= int(experiment["readiness_dwell_ticks_required"]):
					second_readiness_reacquired = true
			else:
				second_ready_dwell_ticks = 0

		if floor in torso.get_colliding_bodies():
			torso_contact_ticks += 1
		for limb_value in limbs:
			var limb: Dictionary = limb_value
			if floor in (limb["lower"] as RigidBody3D).get_colliding_bodies():
				var contact_id := String(limb["contact_id"])
				contact_ticks[contact_id] = int(contact_ticks[contact_id]) + 1
			var geometry := _joint_geometry_diagnostics(torso, limb)
			maximum_anchor_error_m = maxf(
				maximum_anchor_error_m, float(geometry["maximum_anchor_error_m"])
			)
			maximum_hinge_axis_error_rad = maxf(
				maximum_hinge_axis_error_rad, float(geometry["maximum_axis_error_rad"])
			)

		var joint_torque_additions: Dictionary = {}
		if tick >= int(experiment["settle_complete_tick"]):
			var desired_horizontal_force := Vector3(
				(
					(
						float(experiment["horizontal_position_gain_n_per_m"])
						* (target_center_of_mass.x - center_of_mass.x)
					)
					- (
						float(experiment["horizontal_velocity_gain_ns_per_m"])
						* center_of_mass_velocity.x
					)
				),
				0.0,
				(
					(
						float(experiment["horizontal_position_gain_n_per_m"])
						* (target_center_of_mass.z - center_of_mass.z)
					)
					- (
						float(experiment["horizontal_velocity_gain_ns_per_m"])
						* center_of_mass_velocity.z
					)
				)
			)
			if desired_horizontal_force.length() > float(experiment["maximum_horizontal_force_n"]):
				desired_horizontal_force *= (
					float(experiment["maximum_horizontal_force_n"])
					/ desired_horizontal_force.length()
				)
			var endpoint_gain := float(experiment["support_endpoint_position_gain_n_per_m"])
			var desired_body_shift := target_center_of_mass - initial_center_of_mass
			desired_body_shift.y = 0.0
			desired_body_shift += desired_horizontal_force / (3.0 * endpoint_gain)
			var horizontal_shift := Vector2(desired_body_shift.x, desired_body_shift.z)
			if horizontal_shift.length() > float(experiment["maximum_support_horizontal_shift_m"]):
				horizontal_shift *= (
					float(experiment["maximum_support_horizontal_shift_m"])
					/ horizontal_shift.length()
				)
				desired_body_shift.x = horizontal_shift.x
				desired_body_shift.z = horizontal_shift.y
			var vertical_feedback_force := clampf(
				(
					(
						float(experiment["vertical_position_gain_n_per_m"])
						* (initial_center_of_mass.y - center_of_mass.y)
					)
					- (
						float(experiment["vertical_velocity_gain_ns_per_m"])
						* center_of_mass_velocity.y
					)
				),
				-float(experiment["maximum_vertical_correction_n"]),
				float(experiment["maximum_vertical_correction_n"])
			)
			desired_body_shift.y = -(vertical_feedback_force / (3.0 * endpoint_gain))
			for limb_value in limbs:
				var support_limb: Dictionary = limb_value
				var limb_id := String(support_limb["limb_id"])
				if limb_id == excluded_limb_id:
					continue
				var support_target := (
					torso.global_position
					+ (support_relative_world_by_limb[limb_id] as Vector3)
					- desired_body_shift
				)
				var support_result := _task_space_joint_torques(
					support_limb,
					torso,
					support_target,
					torso.linear_velocity,
					endpoint_gain,
					float(experiment["support_endpoint_velocity_gain_ns_per_m"]),
					float(experiment["maximum_support_endpoint_force_n"])
				)
				_merge_torque_additions(
					joint_torque_additions, support_result["joint_torque_overrides"]
				)
			var desired_roll_torque := clampf(
				(
					(
						float(experiment["roll_position_gain_nm_per_rad"])
						* (initial_roll_rad - _signed_roll_rad(torso))
					)
					- (
						float(experiment["roll_velocity_gain_nm_s_per_rad"])
						* torso.angular_velocity.dot(Vector3.RIGHT)
					)
				),
				-float(experiment["maximum_roll_pitch_moment_nm"]),
				float(experiment["maximum_roll_pitch_moment_nm"])
			)
			_merge_torque_additions(
				joint_torque_additions,
				_support_body_axis_torque_additions(
					limbs,
					excluded_limb_id,
					torso,
					desired_roll_torque,
					"hip_abduction",
					Vector3.RIGHT
				)
			)
			var desired_pitch_torque := clampf(
				(
					(
						float(experiment["pitch_position_gain_nm_per_rad"])
						* (initial_pitch_rad - _signed_pitch_rad(torso))
					)
					- (
						float(experiment["pitch_velocity_gain_nm_s_per_rad"])
						* torso.angular_velocity.dot(Vector3.BACK)
					)
				),
				-float(experiment["maximum_roll_pitch_moment_nm"]),
				float(experiment["maximum_roll_pitch_moment_nm"])
			)
			_merge_torque_additions(
				joint_torque_additions,
				_support_body_axis_torque_additions(
					limbs, excluded_limb_id, torso, desired_pitch_torque, "hip_pitch", Vector3.BACK
				)
			)
			support_controller_command_count += 1
			maximum_commanded_support_endpoint_force_n = maxf(
				maximum_commanded_support_endpoint_force_n,
				float(experiment["maximum_support_endpoint_force_n"])
			)

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
			{},
			joint_torque_additions
		)
		if not bool(command_result.get("ok", false)):
			fixture_complete = false
			fixture_failure_code = String(
				command_result.get("failure_code", "SPATIAL_READINESS_RECOVERY_ACTUATION_FAILED")
			)
			break
		all_receipts_complete = all_receipts_complete and bool(command_result["receipts_complete"])
		maximum_pairing_residual_nm = maxf(
			maximum_pairing_residual_nm, float(command_result["maximum_pairing_residual_nm"])
		)
		maximum_applied_torque_nm = maxf(
			maximum_applied_torque_nm, float(command_result["maximum_applied_torque_nm"])
		)
		structural_saturation_count += int(command_result["structural_saturation_count"])
		actuator_saturation_count += int(command_result["actuator_saturation_count"])
		active_command_count += int(command_result["active_command_count"])
		await tree.physics_frame
		executed_ticks = tick + 1
		maximum_height_error_m = maxf(
			maximum_height_error_m,
			absf(torso.global_position.y - float(profile["torso"]["center_world_m"][1]))
		)
		maximum_tilt_rad = maxf(maximum_tilt_rad, _tilt(torso))
		maximum_linear_speed_m_s = maxf(maximum_linear_speed_m_s, torso.linear_velocity.length())
		maximum_angular_speed_rad_s = maxf(
			maximum_angular_speed_rad_s, torso.angular_velocity.length()
		)
		final_com_margin_m = com_margin_m
		final_capture_margin_m = capture_margin_m

	var contact_fractions: Dictionary = {}
	for contact_id in contact_ticks:
		contact_fractions[contact_id] = (
			float(contact_ticks[contact_id]) / float(maxi(executed_ticks, 1))
		)
	var summary := {
		"schema_version": "canonical_spatial_readiness_recovery_summary_v1",
		"profile_id": profile["profile_id"],
		"profile_sha256": profile["profile_sha256"],
		"experiment_id": experiment["experiment_id"],
		"experiment_sha256": experiment["experiment_sha256"],
		"behavior_state": experiment["behavior_state"],
		"controller_id": experiment["controller_id"],
		"seed": seed,
		"second_reacquisition_enabled": second_reacquisition_enabled,
		"fixture_complete": fixture_complete,
		"fixture_failure_code": fixture_failure_code,
		"trial_ticks": trial_ticks,
		"executed_ticks": executed_ticks,
		"first_readiness_acquired": first_readiness_acquired,
		"readiness_loss_established": readiness_loss_established,
		"second_readiness_reacquired": second_readiness_reacquired,
		"longest_first_ready_dwell_ticks": longest_first_ready_dwell_ticks,
		"longest_readiness_loss_dwell_ticks": longest_readiness_loss_dwell_ticks,
		"longest_second_ready_dwell_ticks": longest_second_ready_dwell_ticks,
		"minimum_first_ready_margin_m": minimum_first_ready_margin_m,
		"maximum_loss_margin_m": maximum_loss_margin_m,
		"minimum_second_ready_margin_m": minimum_second_ready_margin_m,
		"final_com_margin_m": final_com_margin_m,
		"final_capture_margin_m": final_capture_margin_m,
		"target_center_of_mass_world_m": target_center_of_mass,
		"final_center_of_mass_world_m":
		_observed_center_of_mass(body_by_id, profile, limbs, excluded_limb_id),
		"support_controller_command_count": support_controller_command_count,
		"maximum_commanded_support_endpoint_force_n": maximum_commanded_support_endpoint_force_n,
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
		"all_receipts_complete": all_receipts_complete,
		"maximum_pairing_residual_nm": maximum_pairing_residual_nm,
		"active_command_count": active_command_count,
		"maximum_applied_torque_nm": maximum_applied_torque_nm,
		"structural_saturation_count": structural_saturation_count,
		"actuator_saturation_count": actuator_saturation_count,
		"maximum_anchor_error_m": maximum_anchor_error_m,
		"maximum_hinge_axis_error_rad": maximum_hinge_axis_error_rad,
		"maximum_height_error_m": maximum_height_error_m,
		"maximum_tilt_rad": maximum_tilt_rad,
		"maximum_linear_speed_m_s": maximum_linear_speed_m_s,
		"maximum_angular_speed_rad_s": maximum_angular_speed_rad_s,
		"final_height_error_m":
		absf(torso.global_position.y - float(profile["torso"]["center_world_m"][1])),
		"final_tilt_rad": _tilt(torso),
		"final_linear_speed_m_s": torso.linear_velocity.length(),
		"final_angular_speed_rad_s": torso.angular_velocity.length(),
		"torso_contact_ticks": torso_contact_ticks,
		"contact_fractions": contact_fractions,
		"observer_values_are_contact_load_measurements": false,
		"per_contact_commands_are_measurements": false,
		"per_foot_measured_load_allocation_available": false,
		"contact_presence_is_bearing_measurement": false,
		"four_contact_readiness_recovery_established": false,
		"new_protective_contact_established": false,
		"articulated_three_contact_bearing_established": false,
		"locomotor_step_established": false,
		"free_3d_recovery_established": false,
		"step_gait_or_walking_established": false,
		"automatic_creature_guidance_allowed": false,
	}
	viewport.queue_free()
	await tree.physics_frame
	await tree.process_frame
	return {"ok": fixture_complete, "summary": summary}


static func _phase_target(
	tick: int,
	experiment: Dictionary,
	initial_target: Vector3,
	ready_target: Vector3,
	second_reacquisition_enabled: bool
) -> Vector3:
	var settle_tick := int(experiment["settle_complete_tick"])
	var first_complete_tick := int(experiment["first_acquisition_complete_tick"])
	var first_window_end_tick := int(experiment["first_ready_window_end_tick"])
	var loss_complete_tick := int(experiment["readiness_loss_complete_tick"])
	var loss_window_end_tick := int(experiment["readiness_loss_window_end_tick"])
	var second_complete_tick := int(experiment["second_acquisition_complete_tick"])
	if tick < settle_tick:
		return initial_target
	if tick < first_complete_tick:
		return initial_target.lerp(
			ready_target,
			_smoothstep(float(tick - settle_tick) / float(first_complete_tick - settle_tick))
		)
	if tick < first_window_end_tick:
		return ready_target
	if tick < loss_complete_tick:
		return ready_target.lerp(
			initial_target,
			_smoothstep(
				(
					float(tick - first_window_end_tick)
					/ float(loss_complete_tick - first_window_end_tick)
				)
			)
		)
	if tick < loss_window_end_tick or not second_reacquisition_enabled:
		return initial_target
	if tick < second_complete_tick:
		return initial_target.lerp(
			ready_target,
			_smoothstep(
				(
					float(tick - loss_window_end_tick)
					/ float(second_complete_tick - loss_window_end_tick)
				)
			)
		)
	return ready_target


static func _observed_center_of_mass(
	body_by_id: Dictionary, profile: Dictionary, limbs: Array, excluded_limb_id: String
) -> Vector3:
	var observation := ReadinessObserverScript.observe(
		body_by_id,
		_support_points_world(limbs, excluded_limb_id, false),
		float(profile["gravity_m_s2"])
	)
	if not bool(observation.get("ok", false)):
		return Vector3(INF, INF, INF)
	return observation["center_of_mass_world_m"]
