class_name LabExistingContactBraceRig
extends "res://scripts/lab/rigs/planar_two_leg_stance_rig.gd"
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## BR9 live paired existing-contact brace fixture.
##
## This deliberately reuses the certified BR7 two-leg planar support geometry,
## force map, paired finite actuators, ordinary distal contacts, material
## out-of-plane guide, command ledger, executor, and receipts. The BR9
## intervention begins only on the first post-impulse observation. Its no-brace
## control retains height/joint support but requests zero pitch-arrest moment.

const BraceControllerScript := preload("res://scripts/lab/mechanics/brace_controller.gd")


func run_trial(
	tree: SceneTree, configuration: Dictionary, actuator_spec: Dictionary, brace_enabled: bool
) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "BR9_ExistingContactBrace"
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var world := Node3D.new()
	world.name = "BR9_ExistingContactBraceWorld"
	var baseline := float(configuration["baseline_height_m"])
	var foot_radius := float(configuration["foot_radius_m"])
	var link_length := float(configuration["link_length_m"])
	var cosine := (baseline - foot_radius) / (2.0 * link_length)
	if cosine <= 0.0 or cosine > 1.0:
		viewport.queue_free()
		await tree.physics_frame
		return {"ok": false, "failure_code": "BR9_INITIAL_IK_INVALID"}
	var alpha := acos(cosine)
	var root_position := Vector3(0.0, baseline, 0.0)
	var root := _build_root(root_position, float(configuration["root_mass_kg"]))
	var anchor := _build_anchor(root_position)
	var guide := _build_planar_guide(root_position)
	var floor := _build_floor(float(configuration["friction_coefficient"]))
	var left := _build_leg(
		"left",
		root_position + Vector3.LEFT * float(configuration["hip_half_span_m"]),
		alpha,
		configuration
	)
	var right := _build_leg(
		"right",
		root_position + Vector3.RIGHT * float(configuration["hip_half_span_m"]),
		-alpha,
		configuration
	)
	for node in [
		anchor,
		root,
		left["link_1"],
		left["link_2"],
		right["link_1"],
		right["link_2"],
		guide,
		left["hip_hinge"],
		left["knee_hinge"],
		right["hip_hinge"],
		right["knee_hinge"],
		floor,
	]:
		world.add_child(node)
	viewport.add_child(world)
	guide.node_a = guide.get_path_to(anchor)
	guide.node_b = guide.get_path_to(root)
	for leg in [left, right]:
		var hip_hinge: HingeJoint3D = leg["hip_hinge"]
		var knee_hinge: HingeJoint3D = leg["knee_hinge"]
		var link_1: RigidBody3D = leg["link_1"]
		var link_2: RigidBody3D = leg["link_2"]
		hip_hinge.node_a = hip_hinge.get_path_to(root)
		hip_hinge.node_b = hip_hinge.get_path_to(link_1)
		knee_hinge.node_a = knee_hinge.get_path_to(link_1)
		knee_hinge.node_b = knee_hinge.get_path_to(link_2)
	await tree.process_frame
	await tree.physics_frame
	for body in [root, left["link_1"], left["link_2"], right["link_1"], right["link_2"]]:
		(body as RigidBody3D).freeze = false
		(body as RigidBody3D).sleeping = false
	_reset_root_and_leg(root, left, root_position)
	_reset_root_and_leg(root, right, root_position)

	var bodies := {
		ROOT_ID: root,
		String(left["link_1_id"]): left["link_1"],
		String(left["link_2_id"]): left["link_2"],
		String(right["link_1_id"]): right["link_1"],
		String(right["link_2_id"]): right["link_2"],
	}
	var measured_bodies: Array[RigidBody3D] = [
		root, left["link_1"], left["link_2"], right["link_1"], right["link_2"]
	]
	var gravity_vector := _gravity_acceleration_world()
	var gravity := gravity_vector.length()
	var total_mass := 0.0
	for body in measured_bodies:
		total_mass += body.mass
	var total_weight := total_mass * gravity
	var step_s := 1.0 / float(configuration["physics_hz"])
	var receipt_sink = ReceiptSinkScript.new(
		"br9_existing_contact_brace" if brace_enabled else "br9_no_brace_control"
	)
	var controller = BraceControllerScript.new()
	var controller_setup := controller.configure(
		configuration["brace_configuration"], 0.5 * total_weight, 0.5 * total_weight
	)
	if not bool(controller_setup.get("ok", false)):
		viewport.queue_free()
		await tree.physics_frame
		return {
			"ok": false,
			"failure_code": "BR9_CONTROLLER_CONFIGURATION_INVALID",
			"details": controller_setup,
		}

	var fixture_complete := true
	var all_receipts_complete := true
	var executed_ticks := 0
	var disturbance_count := 0
	var brace_command_count := 0
	var first_brace_command_tick := -1
	var stabilize_handoff_tick := -1
	var controller_rate_limited_count := 0
	var maximum_command_moment_residual := 0.0
	var maximum_realized_moment_residual := 0.0
	var maximum_normal_load_rate := 0.0
	var maximum_tangent_load_rate := 0.0
	var maximum_pairing_residual := 0.0
	var maximum_applied_torque := 0.0
	var actuator_saturation_count := 0
	var post_impulse_angular_momentum := 0.0
	var final_angular_momentum := 0.0
	var evaluation_angular_momentum := 0.0
	var angular_momentum_abs_area := 0.0
	var maximum_pitch_excursion := 0.0
	var signed_pitch_excursion := 0.0
	var post_disturbance_samples := 0
	var left_post_contact_samples := 0
	var right_post_contact_samples := 0
	var maximum_height_error := 0.0
	var last_left_normal := 0.5 * total_weight
	var last_right_normal := 0.5 * total_weight
	var command_handoff_state := "NO_BRACE_CONTROL"
	var last_controller_failure: Dictionary = {}
	var evaluation_tick := (
		int(configuration["disturbance_tick"]) + int(configuration["evaluation_delay_ticks"])
	)

	for tick in int(configuration["trial_end_tick"]):
		var before_linear := _linear_samples(measured_bodies)
		var before_angular := _angular_momentum_about_com(measured_bodies)
		var known_angular_impulse := 0.0
		if tick == int(configuration["disturbance_tick"]):
			known_angular_impulse = float(configuration["pitch_impulse_n_m_s"])
			root.apply_torque_impulse(PITCH_AXIS * known_angular_impulse)
			disturbance_count += 1
		var left_bearing := floor in (left["link_2"] as RigidBody3D).get_colliding_bodies()
		var right_bearing := floor in (right["link_2"] as RigidBody3D).get_colliding_bodies()
		var com := _system_com(measured_bodies)
		var left_foot := _foot_position(left, link_length)
		var right_foot := _foot_position(right, link_length)
		var pitch := _root_pitch(root)
		var pitch_rate := root.angular_velocity.dot(PITCH_AXIS)
		var desired_vertical := clampf(
			(
				total_weight
				+ (
					float(configuration["height_position_gain_n_m"])
					* (baseline - root.global_position.y)
				)
				- float(configuration["height_velocity_gain_n_s_m"]) * root.linear_velocity.y
			),
			0.75 * total_weight,
			2.0 * float(configuration["maximum_contact_normal_n"])
		)
		var left_support_x := left_foot.x - com.x
		var right_support_x := right_foot.x - com.x
		var left_normal := 0.0
		var right_normal := 0.0
		var desired_moment := 0.0
		var brace_command: Dictionary = {}
		if brace_enabled and tick > int(configuration["disturbance_tick"]):
			var controller_result: Dictionary = (
				controller
				. update(
					{
						"schema_version": "existing_contact_brace_request_v1",
						"tick": tick,
						"detector_state": "BRACE",
						"angular_momentum_z_kg_m2_s": before_angular,
						"pitch_error_rad": pitch,
						"pitch_rate_rad_s": pitch_rate,
						"desired_force_x_n": 0.0,
						"desired_force_y_n": desired_vertical,
						"left_support_x_m": left_support_x,
						"right_support_x_m": right_support_x,
						"left_bearing": left_bearing,
						"right_bearing": right_bearing,
						"friction_coefficient": float(configuration["friction_coefficient"]),
						"minimum_normal_n": 0.0,
						"maximum_normal_n": float(configuration["maximum_contact_normal_n"]),
						"dt_s": step_s,
					}
				)
			)
			if not bool(controller_result.get("ok", false)):
				fixture_complete = false
				last_controller_failure = controller_result
				break
			brace_command = controller_result["command"]
			left_normal = float(brace_command["left"]["normal_force_n"])
			right_normal = float(brace_command["right"]["normal_force_n"])
			desired_moment = float(brace_command["achieved_command_moment_z_nm"])
			brace_command_count += 1
			if first_brace_command_tick < 0:
				first_brace_command_tick = tick
			controller_rate_limited_count += int(brace_command["rate_limited"])
			maximum_command_moment_residual = maxf(
				maximum_command_moment_residual, absf(float(brace_command["moment_residual_z_nm"]))
			)
			maximum_normal_load_rate = maxf(
				maximum_normal_load_rate, float(brace_command["normal_load_rate_n_s"])
			)
			maximum_tangent_load_rate = maxf(
				maximum_tangent_load_rate, float(brace_command["tangent_load_rate_n_s"])
			)
			command_handoff_state = String(brace_command["handoff_state"])
			if command_handoff_state == "STABILIZE" and stabilize_handoff_tick < 0:
				stabilize_handoff_tick = tick
		else:
			var prebrace_moment := 0.0
			if tick <= int(configuration["disturbance_tick"]):
				prebrace_moment = (
					-float(configuration["prebrace_pitch_position_gain_nm_rad"]) * pitch
					- float(configuration["prebrace_pitch_velocity_gain_nm_s_rad"]) * pitch_rate
				)
			var allocation_result := (
				AllocatorScript
				. allocate(
					{
						"schema_version": "planar_contact_allocation_request_v1",
						"tick": tick,
						"desired_force_x_n": 0.0,
						"desired_force_y_n": desired_vertical,
						"desired_moment_z_nm": prebrace_moment,
						"left_support_x_m": left_support_x,
						"right_support_x_m": right_support_x,
						"left_bearing": true,
						"right_bearing": true,
						"friction_coefficient": float(configuration["friction_coefficient"]),
						"minimum_normal_n": 0.0,
						"maximum_normal_n": float(configuration["maximum_contact_normal_n"]),
						"feasibility_tolerance": 1.0e-8,
					}
				)
			)
			if (
				not bool(allocation_result.get("ok", false))
				or not bool(allocation_result["allocation"]["feasible"])
			):
				fixture_complete = false
				break
			var allocation: Dictionary = allocation_result["allocation"]
			left_normal = float(allocation["left"]["normal_force_n"])
			right_normal = float(allocation["right"]["normal_force_n"])
			desired_moment = prebrace_moment
		last_left_normal = left_normal
		last_right_normal = right_normal

		var plans: Array = []
		var left_plans := _leg_plans(
			tick, root, left, left_normal, configuration, actuator_spec, gravity, left_foot
		)
		var right_plans := _leg_plans(
			tick, root, right, right_normal, configuration, actuator_spec, gravity, right_foot
		)
		if not bool(left_plans.get("ok", false)) or not bool(right_plans.get("ok", false)):
			fixture_complete = false
			break
		plans.append_array(left_plans["plans"])
		plans.append_array(right_plans["plans"])
		var ledger = CommandLedgerScript.new()
		fixture_complete = ledger.begin_tick(tick) and fixture_complete
		for plan_value in plans:
			fixture_complete = (
				ledger.queue_joint((plan_value as Dictionary)["command"]) and fixture_complete
			)
		var envelope := (
			ledger
			. seal(
				{
					"run_id":
					"br9_existing_contact_brace" if brace_enabled else "br9_no_brace_control",
					"command_id": tick,
					"source_frame_id": tick,
					"applied_transition": [tick, tick + 1],
					"mode":
					(
						"BR9_EXISTING_CONTACT_BRACE"
						if brace_enabled and tick > int(configuration["disturbance_tick"])
						else "BR9_NO_BRACE_CONTROL"
					),
				}
			)
		)
		var before_receipts := receipt_sink.values().size()
		var execution := ActuationExecutorScript.apply_command_envelope(
			envelope, bodies, receipt_sink
		)
		await tree.physics_frame
		executed_ticks = tick + 1
		for body in measured_bodies:
			body.sleeping = false
		var receipts: Array = receipt_sink.values().slice(before_receipts)
		var operations: Array = []
		for plan_value in plans:
			operations.append_array(
				(plan_value as Dictionary)["command"]["planned_application_operations"]
			)
		var receipts_match := _receipts_match(
			receipts, String(envelope["command_payload_sha256"]), operations
		)
		all_receipts_complete = all_receipts_complete and receipts_match
		fixture_complete = (
			fixture_complete
			and bool(execution.get("ok", false))
			and int(execution.get("applied_count", -1)) == 8
			and receipts_match
		)
		var after_linear := _linear_samples(measured_bodies)
		var after_angular := _angular_momentum_about_com(measured_bodies)
		var reconstruction := ReconstructorScript.reconstruct(
			before_linear, after_linear, step_s, total_mass * gravity_vector * step_s, Vector3.UP
		)
		if not bool(reconstruction.get("reconstruction_valid", false)):
			fixture_complete = false
			break
		var reconstructed_moment := (
			(after_angular - before_angular - known_angular_impulse) / step_s
		)
		if brace_enabled and tick > int(configuration["disturbance_tick"]):
			maximum_realized_moment_residual = maxf(
				maximum_realized_moment_residual, absf(reconstructed_moment - desired_moment)
			)
		for plan_value in plans:
			var plan: Dictionary = plan_value
			var resolution: Dictionary = plan["resolution"]
			maximum_pairing_residual = maxf(
				maximum_pairing_residual,
				float((plan["command"]["diagnostics"] as Dictionary)["pairing_residual_nm"])
			)
			maximum_applied_torque = maxf(
				maximum_applied_torque, absf(float(resolution["applied_total_nm"]))
			)
			actuator_saturation_count += int(_resolution_saturated(resolution))
			_update_leg_state(plan)
		if tick == int(configuration["disturbance_tick"]):
			post_impulse_angular_momentum = after_angular
		if tick >= int(configuration["disturbance_tick"]):
			post_disturbance_samples += 1
			left_post_contact_samples += int(left_bearing)
			right_post_contact_samples += int(right_bearing)
			angular_momentum_abs_area += absf(after_angular) * step_s
			var current_pitch := _root_pitch(root)
			if absf(current_pitch) > maximum_pitch_excursion:
				maximum_pitch_excursion = absf(current_pitch)
				signed_pitch_excursion = current_pitch
			maximum_height_error = maxf(
				maximum_height_error, absf(root.global_position.y - baseline)
			)
		if tick == evaluation_tick:
			evaluation_angular_momentum = after_angular
		final_angular_momentum = after_angular

	var planar_guide_exact := _planar_guide_exact(guide)
	var hinges_exact := (
		_hinge_exact(left["hip_hinge"])
		and _hinge_exact(left["knee_hinge"])
		and _hinge_exact(right["hip_hinge"])
		and _hinge_exact(right["knee_hinge"])
	)
	viewport.queue_free()
	await tree.process_frame
	await tree.physics_frame
	return {
		"ok": true,
		"summary":
		{
			"schema_version": "existing_contact_brace_fixture_summary_v1",
			"configuration_sha256": String(configuration.get("configuration_sha256", "")),
			"actuator_spec_sha256": String(actuator_spec.get("spec_sha256", "")),
			"fixture_complete": fixture_complete,
			"brace_enabled": brace_enabled,
			"executed_ticks": executed_ticks,
			"planar_guide_exact": planar_guide_exact,
			"hinges_exact": hinges_exact,
			"all_receipts_complete": all_receipts_complete,
			"disturbance_operation_count": disturbance_count,
			"first_brace_command_tick": first_brace_command_tick,
			"brace_command_count": brace_command_count,
			"stabilize_handoff_tick": stabilize_handoff_tick,
			"command_handoff_state": command_handoff_state,
			"controller_rate_limited_count": controller_rate_limited_count,
			"maximum_command_moment_residual_nm": maximum_command_moment_residual,
			"maximum_realized_moment_residual_nm": maximum_realized_moment_residual,
			"maximum_normal_load_rate_n_s": maximum_normal_load_rate,
			"maximum_tangent_load_rate_n_s": maximum_tangent_load_rate,
			"maximum_pairing_residual_nm": maximum_pairing_residual,
			"maximum_applied_torque_nm": maximum_applied_torque,
			"actuator_saturation_count": actuator_saturation_count,
			"post_impulse_angular_momentum_z_kg_m2_s": post_impulse_angular_momentum,
			"evaluation_angular_momentum_z_kg_m2_s": evaluation_angular_momentum,
			"final_angular_momentum_z_kg_m2_s": final_angular_momentum,
			"angular_momentum_abs_area_kg_m2": angular_momentum_abs_area,
			"maximum_pitch_excursion_rad": maximum_pitch_excursion,
			"signed_pitch_excursion_rad": signed_pitch_excursion,
			"maximum_height_error_m": maximum_height_error,
			"left_existing_contact_fraction":
			float(left_post_contact_samples) / float(maxi(post_disturbance_samples, 1)),
			"right_existing_contact_fraction":
			float(right_post_contact_samples) / float(maxi(post_disturbance_samples, 1)),
			"post_disturbance_sample_count": post_disturbance_samples,
			"last_left_command_normal_n": last_left_normal,
			"last_right_command_normal_n": last_right_normal,
			"last_controller_failure": last_controller_failure,
			"root_rescue_operation_count": 0,
			"foot_pin_operation_count": 0,
			"new_support_contact_operation_count": 0,
			"per_contact_commands_are_measurements": false,
			"per_foot_measured_load_allocation_available": false,
			"automatic_creature_guidance_operation_count": 0,
		},
	}
