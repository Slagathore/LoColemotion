class_name LabReachableCatchStepRig
extends "res://scripts/lab/rigs/bounded_touchdown_rig.gd"
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## BR10 live planar reachable-catch fixture.
##
## One ordinary left distal contact carries the assembly during the settling
## phase. The observed right distal sphere is unloaded and clear of the floor.
## After one declared pitch impulse, the pure planner selects a new support-
## expanding target. Finite paired joint commands swing the right limb to a
## real semantic floor contact; only observed contact/load may advance the
## coordinator. Once bearing, ordinary two-contact allocation arrests pitch
## and must return the scaffolded body to a declared stable dwell.

const PlannerScript := preload("res://scripts/lab/mechanics/reachable_catch_step_planner.gd")
const SagittalForceMapScript := preload("res://scripts/lab/mechanics/sagittal_contact_force_map.gd")


func run_trial(
	tree: SceneTree, configuration: Dictionary, actuator_spec: Dictionary, catch_enabled: bool
) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "BR10_ReachableCatchStep"
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var world := Node3D.new()
	world.name = "BR10_ReachableCatchStepWorld"
	var clock = CaptureClockScript.new()
	var baseline := float(configuration["baseline_height_m"])
	var radius := float(configuration["foot_radius_m"])
	var length := float(configuration["link_length_m"])
	var cosine := (baseline - radius) / (2.0 * length)
	if cosine <= 0.0 or cosine > 1.0:
		viewport.queue_free()
		await tree.process_frame
		return {"ok": false, "failure_code": "BR10_LEFT_SUPPORT_IK_INVALID"}
	var alpha := acos(cosine)
	var root_position := Vector3(0.0, baseline, 0.0)
	var root := _build_root(root_position, float(configuration["root_mass_kg"]))
	var anchor := _build_anchor(root_position)
	var guide := _build_planar_guide(root_position)
	var floor := _build_semantic_floor()
	var material := PhysicsMaterial.new()
	material.friction = float(configuration["friction_coefficient"])
	material.bounce = 0.0
	floor.physics_material_override = material
	var left := _build_leg("br10_left", root_position, alpha, configuration)
	var right_result := _build_touchdown_leg(root_position, configuration, clock)
	if not bool(right_result.get("ok", false)):
		viewport.queue_free()
		await tree.process_frame
		return right_result
	var right: Dictionary = right_result["leg"]
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
	(right["link_2"] as RigidBody3D).add_collision_exception_with(left["link_2"])
	(left["link_2"] as RigidBody3D).add_collision_exception_with(right["link_2"])
	await tree.process_frame
	await tree.physics_frame
	for body in [left["link_1"], left["link_2"], right["link_1"], right["link_2"]]:
		(body as RigidBody3D).freeze = false
		(body as RigidBody3D).sleeping = false
	_reset_root_and_leg(root, left, root_position)
	_reset_root_and_leg(root, right, root_position)

	var coordinator = CoordinatorScript.new()
	var phase_configuration := {
		"schema_version": "catch_contact_phase_configuration_v1",
		"support_id": FLOOR_ID,
		"contact_confirm_ticks": int(configuration["contact_confirm_ticks"]),
		"load_confirm_ticks": int(configuration["load_confirm_ticks"]),
		"bearing_confirm_ticks": int(configuration["bearing_confirm_ticks"]),
		"load_enter_n": float(configuration["load_enter_n"]),
		"bearing_enter_n": float(configuration["bearing_enter_n"]),
		"maximum_separating_speed_m_s": float(configuration["maximum_separating_speed_m_s"]),
	}
	var phase_setup := coordinator.configure(phase_configuration)
	var planner_setup := PlannerScript.compile(configuration["planner_configuration"])
	if not bool(phase_setup.get("ok", false)) or not bool(planner_setup.get("ok", false)):
		viewport.queue_free()
		await tree.process_frame
		return {"ok": false, "failure_code": "BR10_COMPONENT_CONFIGURATION_INVALID"}
	var planner_configuration: Dictionary = planner_setup["configuration"]
	var handoff_configuration := configuration.duplicate(true)
	handoff_configuration["joint_position_gain_nm_rad"] = float(
		configuration["handoff_joint_position_gain_nm_rad"]
	)
	handoff_configuration["joint_velocity_gain_nm_s_rad"] = float(
		configuration["handoff_joint_velocity_gain_nm_s_rad"]
	)

	var right_link_2: Variant = right["link_2"]
	var bodies := {
		ROOT_ID: root,
		String(left["link_1_id"]): left["link_1"],
		String(left["link_2_id"]): left["link_2"],
		String(right["link_1_id"]): right["link_1"],
		String(right["link_2_id"]): right["link_2"],
	}
	var measured_bodies: Array[RigidBody3D] = [
		root,
		left["link_1"],
		left["link_2"],
		right["link_1"],
		right["link_2"],
	]
	var total_mass := 0.0
	for body in measured_bodies:
		total_mass += body.mass
	var gravity := _gravity_acceleration_world().length()
	var total_weight := total_mass * gravity
	var step_s := 1.0 / float(configuration["physics_hz"])
	var receipt_sink = ReceiptSinkScript.new(
		"br10_reachable_catch" if catch_enabled else "br10_no_catch_control"
	)
	var fixture_complete := true
	var fixture_failure_code := ""
	var all_receipts_complete := true
	var contact_capacity_complete := true
	var executed_ticks := 0
	var disturbance_count := 0
	var root_release_count := 0
	var left_bearing_at_release := false
	var catch_plan_count := 0
	var catch_command_count := 0
	var first_catch_command_tick := -1
	var planner_selected := false
	var planner_failure_code := ""
	var selected_candidate_id := ""
	var predicted_contact_tick := -1
	var predicted_reach_time_s := -1.0
	var planner_support_improvement := 0.0
	var catch_target_world := Vector3(INF, INF, INF)
	var catch_start_foot_world := Vector3(INF, INF, INF)
	var first_touch_tick := -1
	var first_load_tick := -1
	var first_bearing_tick := -1
	var bearing_acquired := false
	var stance_return_tick := -1
	var stance_dwell := 0
	var stance_world_hold_active := false
	var stance_world_hold_command_count := 0
	var left_stance_target_world := Vector3(INF, INF, INF)
	var right_stance_target_world := Vector3(INF, INF, INF)
	var stabilize_handoff_command_count := 0
	var phase_trace: Array[String] = []
	var initial_right_contact_count := 0
	var touchdown_approach_speed := 0.0
	var peak_predicted_load := 0.0
	var non_distal_contact_count := 0
	var support_interval_before := 0.0
	var support_interval_after := 0.0
	var measured_support_improvement := 0.0
	var horizontal_reference_x := INF
	var maximum_horizontal_position_error := 0.0
	var maximum_horizontal_speed := 0.0
	var maximum_commanded_tangent := 0.0
	var maximum_applied_torque := 0.0
	var maximum_pairing_residual := 0.0
	var actuator_saturation_count := 0
	var allocator_clamp_count := 0
	var maximum_normal_load_rate := 0.0
	var previous_left_normal := total_weight
	var previous_right_normal := 0.0
	var maximum_pitch_excursion := 0.0
	var maximum_height_error := 0.0
	var post_stance_sample_count := 0
	var post_stance_bearing_loss_count := 0
	var maximum_post_stance_pitch_error := 0.0
	var maximum_post_stance_pitch_rate := 0.0
	var maximum_post_stance_height_error := 0.0
	var post_impulse_pitch_rate := 0.0
	var pitch_at_first_bearing := 0.0
	var final_pitch := 0.0
	var final_pitch_rate := 0.0
	var final_height_error := 0.0
	var target_arrival_used_for_transition := false
	var local_load_is_generalized_per_foot_allocation := false
	var target_q1 := float(configuration["target_q1_rad"])
	var target_q2 := float(configuration["target_q2_rad"])
	var initial_q1 := float(configuration["initial_q1_rad"])
	var initial_q2 := float(configuration["initial_q2_rad"])
	var catch_start := int(configuration["catch_start_tick"])
	var disturbance_tick := int(configuration["disturbance_tick"])

	for tick in int(configuration["trial_end_tick"]):
		var left_foot := _foot_position(left, length)
		var right_foot := _foot_position(right, length)
		if tick < disturbance_tick and floor in right_link_2.get_colliding_bodies():
			initial_right_contact_count += 1
		if tick == disturbance_tick:
			left_bearing_at_release = (
				floor in (left["link_2"] as RigidBody3D).get_colliding_bodies()
			)
			root.freeze = false
			root.sleeping = false
			root_release_count += 1
			root.apply_torque_impulse(-PITCH_AXIS * float(configuration["pitch_impulse_n_m_s"]))
			disturbance_count += 1
		if catch_enabled and tick == catch_start:
			var current_support_min := left_foot.x - radius
			var current_support_max := left_foot.x + radius
			var candidate_target_local: Array = configuration["target_foot_local_m"]
			var target_world_x := root.global_position.x + float(candidate_target_local[0])
			var plan_result := (
				PlannerScript
				. plan(
					planner_configuration,
					{
						"schema_version": "reachable_catch_step_request_v1",
						"tick": tick,
						"detector_state": "BRACE",
						"reaction_deadline_s": float(configuration["reaction_deadline_s"]),
						"current_support_min_x_m": current_support_min,
						"current_support_max_x_m": current_support_max,
						"hip_world_x_m": root.global_position.x,
						"hip_world_y_m": root.global_position.y,
						"current_foot_world_x_m": right_foot.x,
						"current_foot_world_y_m": right_foot.y,
						"candidates":
						[
							{
								"candidate_id": "forward_catch",
								"target_world_x_m": target_world_x,
								"target_world_y_m": radius,
								"path_minimum_clearance_m":
								float(configuration["declared_path_clearance_m"]),
								"collision_free": true,
								"friction_feasible": true,
								"torque_feasible": true,
								"preexisting_contact": false,
								"joint_travel_abs_rad":
								[absf(target_q1 - initial_q1), absf(target_q2 - initial_q2)],
								"joint_speed_bounds_rad_s":
								configuration["planner_joint_speed_bounds_rad_s"],
							}
						],
					}
				)
			)
			catch_plan_count += 1
			if not bool(plan_result.get("ok", false)):
				fixture_complete = false
				planner_failure_code = String(plan_result.get("failure_code", ""))
				break
			var catch_plan: Dictionary = plan_result["plan"]
			planner_selected = bool(catch_plan["selected"])
			planner_failure_code = String(catch_plan["failure_code"])
			selected_candidate_id = String(catch_plan["selected_candidate_id"])
			predicted_contact_tick = int(catch_plan["predicted_contact_tick"])
			predicted_reach_time_s = float(catch_plan["predicted_reach_time_s"])
			if planner_selected:
				var selected: Dictionary = {}
				for candidate_value in catch_plan["candidates"]:
					var candidate: Dictionary = candidate_value
					if String(candidate["candidate_id"]) == selected_candidate_id:
						selected = candidate
						break
				planner_support_improvement = float(selected.get("support_improvement_m", 0.0))
				catch_start_foot_world = right_foot
				catch_target_world = Vector3(
					float(selected["target_world_x_m"]),
					radius - float(configuration["catch_target_penetration_m"]),
					0.0
				)
			else:
				fixture_complete = false
				break

		var catch_fraction := 0.0
		if catch_enabled and tick >= catch_start and planner_selected:
			catch_fraction = clampf(
				float(tick - catch_start + 1) / float(configuration["catch_ramp_ticks"]), 0.0, 1.0
			)
			catch_command_count += 1
			if first_catch_command_tick < 0:
				first_catch_command_tick = tick
		var smooth_fraction := catch_fraction * catch_fraction * (3.0 - 2.0 * catch_fraction)
		if stance_world_hold_active:
			var left_stance_ik := _world_target_ik(root, left_stance_target_world, length)
			var right_stance_ik := _world_target_ik(root, right_stance_target_world, length)
			if (
				not bool(left_stance_ik.get("ok", false))
				or not bool(right_stance_ik.get("ok", false))
			):
				fixture_complete = false
				break
			left["target_q1_rad"] = float(left_stance_ik["q1_rad"])
			left["target_q2_rad"] = float(left_stance_ik["q2_rad"])
			right["target_q1_rad"] = float(right_stance_ik["q1_rad"])
			right["target_q2_rad"] = float(right_stance_ik["q2_rad"])
			stance_world_hold_command_count += 1
		elif catch_enabled and planner_selected:
			var desired_foot_world := catch_start_foot_world.lerp(
				catch_target_world, smooth_fraction
			)
			desired_foot_world.y += (
				4.0
				* float(configuration["catch_path_lift_m"])
				* smooth_fraction
				* (1.0 - smooth_fraction)
			)
			var target_ik := _world_target_ik(root, desired_foot_world, length)
			if not bool(target_ik.get("ok", false)):
				fixture_complete = false
				break
			right["target_q1_rad"] = float(target_ik["q1_rad"])
			right["target_q2_rad"] = float(target_ik["q2_rad"])
		else:
			right["target_q1_rad"] = initial_q1
			right["target_q2_rad"] = initial_q2

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
			0.5 * total_weight,
			2.0 * float(configuration["maximum_contact_normal_n"])
		)
		var left_normal := desired_vertical
		var right_normal := 0.0
		var left_tangent := 0.0
		var right_tangent := 0.0
		var bearing_load_commanded := false
		var maximum_normal_step := float(configuration["maximum_normal_load_rate_n_s"]) * step_s
		if catch_enabled and bearing_acquired and coordinator.phase() in ["LOAD", "BEARING"]:
			bearing_load_commanded = true
			desired_vertical = clampf(
				desired_vertical,
				previous_left_normal + previous_right_normal - 2.0 * maximum_normal_step,
				previous_left_normal + previous_right_normal + 2.0 * maximum_normal_step
			)
			var com := _system_com(measured_bodies)
			var desired_horizontal := clampf(
				(
					(
						-float(configuration["horizontal_position_gain_n_m"])
						* (root.global_position.x - horizontal_reference_x)
					)
					- (
						float(configuration["horizontal_velocity_gain_n_s_m"])
						* root.linear_velocity.x
					)
				),
				(
					-float(configuration["horizontal_friction_reserve_fraction"])
					* float(configuration["friction_coefficient"])
					* desired_vertical
				),
				(
					float(configuration["horizontal_friction_reserve_fraction"])
					* float(configuration["friction_coefficient"])
					* desired_vertical
				)
			)
			maximum_horizontal_position_error = maxf(
				maximum_horizontal_position_error,
				absf(root.global_position.x - horizontal_reference_x)
			)
			maximum_horizontal_speed = maxf(maximum_horizontal_speed, absf(root.linear_velocity.x))
			maximum_commanded_tangent = maxf(maximum_commanded_tangent, absf(desired_horizontal))
			var active_pitch_gain := float(
				(
					configuration["pitch_position_gain_nm_rad"]
					if stance_return_tick < 0
					else configuration["handoff_pitch_position_gain_nm_rad"]
				)
			)
			var active_rate_gain := float(
				(
					configuration["pitch_velocity_gain_nm_s_rad"]
					if stance_return_tick < 0
					else configuration["handoff_pitch_velocity_gain_nm_s_rad"]
				)
			)
			stabilize_handoff_command_count += int(stance_return_tick >= 0)
			var desired_moment := -active_pitch_gain * pitch - active_rate_gain * pitch_rate
			var vertical_contact_moment := desired_moment - (com.y - radius) * desired_horizontal
			var left_support_x := left_foot.x - com.x
			var right_support_x := right_foot.x - com.x
			var clamped_moment := _clamp_two_contact_moment(
				vertical_contact_moment,
				desired_vertical,
				left_support_x,
				right_support_x,
				float(configuration["minimum_bearing_command_n"]),
				float(configuration["maximum_contact_normal_n"])
			)
			if not bool(clamped_moment.get("ok", false)):
				fixture_complete = false
				fixture_failure_code = String(clamped_moment.get("failure_code", ""))
				break
			allocator_clamp_count += int(bool(clamped_moment["clamped"]))
			vertical_contact_moment = float(clamped_moment["moment_nm"])
			var allocation_result := (
				AllocatorScript
				. allocate(
					{
						"schema_version": "planar_contact_allocation_request_v1",
						"tick": tick,
						"desired_force_x_n": desired_horizontal,
						"desired_force_y_n": desired_vertical,
						"desired_moment_z_nm": vertical_contact_moment,
						"left_support_x_m": left_support_x,
						"right_support_x_m": right_support_x,
						"left_bearing":
						floor in (left["link_2"] as RigidBody3D).get_colliding_bodies(),
						"right_bearing": true,
						"friction_coefficient": float(configuration["friction_coefficient"]),
						"minimum_normal_n": float(configuration["minimum_bearing_command_n"]),
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
				fixture_failure_code = String(
					allocation_result.get("failure_code", "BR10_CONTACT_ALLOCATION_INFEASIBLE")
				)
				break
			left_normal = float(allocation_result["allocation"]["left"]["normal_force_n"])
			var target_right_normal := float(
				allocation_result["allocation"]["right"]["normal_force_n"]
			)
			var limited_pair := _rate_limit_normal_pair(
				previous_left_normal,
				previous_right_normal,
				left_normal,
				target_right_normal,
				maximum_normal_step,
				float(configuration["minimum_bearing_command_n"]),
				float(configuration["maximum_contact_normal_n"])
			)
			if not bool(limited_pair.get("ok", false)):
				fixture_complete = false
				fixture_failure_code = String(limited_pair.get("failure_code", ""))
				break
			left_normal = float(limited_pair["left_normal_n"])
			right_normal = float(limited_pair["right_normal_n"])
			left_tangent = desired_horizontal * left_normal / desired_vertical
			right_tangent = desired_horizontal * right_normal / desired_vertical
		if bearing_load_commanded:
			maximum_normal_load_rate = maxf(
				maximum_normal_load_rate,
				(
					maxf(
						absf(left_normal - previous_left_normal),
						absf(right_normal - previous_right_normal)
					)
					/ step_s
				)
			)
		previous_left_normal = left_normal
		previous_right_normal = right_normal

		var support_configuration: Dictionary = (
			handoff_configuration if stance_world_hold_active else configuration
		)
		var left_plans := _catch_leg_plans(
			tick,
			root,
			left,
			left_normal,
			left_tangent,
			support_configuration,
			actuator_spec,
			gravity
		)
		var right_plans: Dictionary
		if catch_enabled and bearing_acquired and coordinator.phase() in ["LOAD", "BEARING"]:
			right_plans = _catch_leg_plans(
				tick,
				root,
				right,
				right_normal,
				right_tangent,
				support_configuration,
				actuator_spec,
				gravity
			)
		else:
			right_plans = _swing_plans(tick, root, right, configuration, actuator_spec)
		if not bool(left_plans.get("ok", false)) or not bool(right_plans.get("ok", false)):
			fixture_complete = false
			fixture_failure_code = String(
				(
					left_plans.get("failure_code", "")
					if not bool(left_plans.get("ok", false))
					else right_plans.get("failure_code", "")
				)
			)
			break
		var plans: Array = []
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
					"run_id": "br10_reachable_catch" if catch_enabled else "br10_no_catch_control",
					"command_id": tick,
					"source_frame_id": tick,
					"applied_transition": [tick, tick + 1],
					"mode": "BR10_REACHABLE_CATCH" if catch_enabled else "BR10_NO_CATCH_CONTROL",
				}
			)
		)
		var before_receipts := receipt_sink.values().size()
		clock.open_epoch(tick, float(tick + 1) * step_s, &"integrate_callback")
		var execution := ActuationExecutorScript.apply_command_envelope(
			envelope, bodies, receipt_sink
		)
		await tree.physics_frame
		clock.close_epoch()
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
		for plan_value in plans:
			var plan: Dictionary = plan_value
			var resolution: Dictionary = plan["resolution"]
			maximum_applied_torque = maxf(
				maximum_applied_torque, absf(float(resolution["applied_total_nm"]))
			)
			maximum_pairing_residual = maxf(
				maximum_pairing_residual,
				float((plan["command"]["diagnostics"] as Dictionary)["pairing_residual_nm"])
			)
			actuator_saturation_count += int(_resolution_saturated(resolution))
			_update_leg_state(plan)

		var diagnostics: Dictionary = right_link_2.latest_contact_v2_diagnostics.get(
			"observation", {}
		)
		contact_capacity_complete = (
			contact_capacity_complete
			and bool(diagnostics.get("finite", false))
			and not bool(diagnostics.get("saturated_ever", true))
		)
		var distal_contacts: Array = []
		for raw_value in right_link_2.latest_contacts_v2:
			var raw: Dictionary = raw_value
			if (
				int(raw.get("physics_step_id", -1)) != tick
				or String(raw.get("counterparty_semantic_id", "")) != FLOOR_ID
			):
				continue
			if String(raw.get("observed_shape_semantic_id", "")) == DISTAL_SHAPE_ID:
				distal_contacts.append(raw)
			else:
				non_distal_contact_count += 1
		var pressure := PressureObserverScript.observe_raw_points(
			distal_contacts, tick, FLOOR_ID, step_s, Vector3.UP
		)
		var load_available := bool(pressure.get("observation_valid", false))
		var normal_load: Variant = (
			float(pressure["predicted_normal_load_n"]) if load_available else null
		)
		if load_available:
			peak_predicted_load = maxf(peak_predicted_load, float(normal_load))
		var separation_available := not distal_contacts.is_empty()
		var maximum_separation_speed := -INF
		var maximum_approach_speed := 0.0
		for raw_value in distal_contacts:
			var raw: Dictionary = raw_value
			var normal: Vector3 = raw["normal_world"]
			var relative: Vector3 = raw["relative_velocity_world_mps"]
			var separation := relative.dot(normal.normalized())
			maximum_separation_speed = maxf(maximum_separation_speed, separation)
			maximum_approach_speed = maxf(maximum_approach_speed, -separation)
		var ground_contact := not distal_contacts.is_empty()
		if ground_contact and first_touch_tick < 0:
			touchdown_approach_speed = maximum_approach_speed
		var phase_update := (
			coordinator
			. update(
				{
					"schema_version": "catch_contact_phase_observation_v1",
					"tick": tick,
					"target_arrived": catch_enabled and catch_fraction >= 1.0,
					"ground_contact_observed": ground_contact,
					"ground_qualified": ground_contact,
					"normal_load_available": load_available,
					"normal_load_n": normal_load,
					"relative_separation_speed_available": separation_available,
					"relative_separation_speed_m_s":
					maximum_separation_speed if separation_available else null,
				}
			)
		)
		if not bool(phase_update.get("ok", false)):
			fixture_complete = false
			break
		var phase_result: Dictionary = phase_update["result"]
		var phase := String(phase_result["phase"])
		if bool(phase_result["transitioned"]):
			phase_trace.append(phase)
		target_arrival_used_for_transition = (
			target_arrival_used_for_transition
			or bool(phase_result["target_arrival_used_for_transition"])
		)
		local_load_is_generalized_per_foot_allocation = (
			local_load_is_generalized_per_foot_allocation
			or bool(phase_result["local_load_is_generalized_per_foot_allocation"])
		)
		if phase == "TOUCH" and first_touch_tick < 0:
			first_touch_tick = tick + 1
		if phase == "LOAD" and first_load_tick < 0:
			first_load_tick = tick + 1
		if phase == "BEARING" and first_bearing_tick < 0:
			first_bearing_tick = tick + 1
			bearing_acquired = true
			horizontal_reference_x = root.global_position.x
			pitch_at_first_bearing = _root_pitch(root)
			var com := _system_com(measured_bodies)
			var current_left := _foot_position(left, length)
			var current_right := _foot_position(right, length)
			catch_target_world = (
				current_right + Vector3.DOWN * float(configuration["catch_target_penetration_m"])
			)
			var before_min := current_left.x - radius
			var before_max := current_left.x + radius
			var after_min := minf(before_min, current_right.x - radius)
			var after_max := maxf(before_max, current_right.x + radius)
			support_interval_before = before_max - before_min
			support_interval_after = after_max - after_min
			measured_support_improvement = support_interval_after - support_interval_before

		var current_pitch := _root_pitch(root)
		var current_pitch_rate := root.angular_velocity.dot(PITCH_AXIS)
		if stance_return_tick >= 0:
			post_stance_sample_count += 1
			post_stance_bearing_loss_count += int(coordinator.phase() != "BEARING")
			maximum_post_stance_pitch_error = maxf(
				maximum_post_stance_pitch_error, absf(current_pitch)
			)
			maximum_post_stance_pitch_rate = maxf(
				maximum_post_stance_pitch_rate, absf(current_pitch_rate)
			)
			maximum_post_stance_height_error = maxf(
				maximum_post_stance_height_error, absf(root.global_position.y - baseline)
			)
		maximum_pitch_excursion = maxf(maximum_pitch_excursion, absf(current_pitch))
		maximum_height_error = maxf(maximum_height_error, absf(root.global_position.y - baseline))
		if tick == disturbance_tick:
			post_impulse_pitch_rate = current_pitch_rate
		var stance_ready := (
			coordinator.phase() == "BEARING"
			and absf(current_pitch) <= float(configuration["stance_pitch_tolerance_rad"])
			and (
				absf(current_pitch_rate)
				<= float(configuration["stance_pitch_rate_tolerance_rad_s"])
			)
			and (
				absf(root.global_position.y - baseline)
				<= float(configuration["stance_height_tolerance_m"])
			)
		)
		stance_dwell = stance_dwell + 1 if stance_ready else 0
		if stance_return_tick < 0 and stance_dwell >= int(configuration["stance_dwell_ticks"]):
			stance_return_tick = tick + 1
			left_stance_target_world = _foot_position(left, length)
			right_stance_target_world = _foot_position(right, length)
			stance_world_hold_active = true

	final_pitch = _root_pitch(root)
	final_pitch_rate = root.angular_velocity.dot(PITCH_AXIS)
	final_height_error = absf(root.global_position.y - baseline)
	var summary := {
		"schema_version": "reachable_catch_step_summary_v1",
		"configuration_sha256": String(configuration.get("configuration_sha256", "")),
		"actuator_spec_sha256": String(actuator_spec.get("spec_sha256", "")),
		"catch_enabled": catch_enabled,
		"fixture_complete": fixture_complete,
		"fixture_failure_code": fixture_failure_code,
		"executed_ticks": executed_ticks,
		"planar_guide_exact": _planar_guide_exact(guide),
		"hinges_exact":
		(
			_hinge_exact(left["hip_hinge"])
			and _hinge_exact(left["knee_hinge"])
			and _hinge_exact(right["hip_hinge"])
			and _hinge_exact(right["knee_hinge"])
		),
		"all_receipts_complete": all_receipts_complete,
		"contact_capacity_complete": contact_capacity_complete,
		"disturbance_operation_count": disturbance_count,
		"root_release_operation_count": root_release_count,
		"left_bearing_at_release": left_bearing_at_release,
		"preparation_root_freeze_released": not root.freeze,
		"catch_plan_count": catch_plan_count,
		"catch_command_count": catch_command_count,
		"first_catch_command_tick": first_catch_command_tick,
		"planner_selected": planner_selected,
		"planner_failure_code": planner_failure_code,
		"selected_candidate_id": selected_candidate_id,
		"predicted_contact_tick": predicted_contact_tick,
		"predicted_reach_time_s": predicted_reach_time_s,
		"planner_support_improvement_m": planner_support_improvement,
		"first_touch_tick": first_touch_tick,
		"first_load_tick": first_load_tick,
		"first_bearing_tick": first_bearing_tick,
		"final_phase": coordinator.phase(),
		"phase_trace": phase_trace,
		"stance_return_tick": stance_return_tick,
		"stance_world_hold_active": stance_world_hold_active,
		"stance_world_hold_command_count": stance_world_hold_command_count,
		"stabilize_handoff_command_count": stabilize_handoff_command_count,
		"touchdown_approach_speed_m_s": touchdown_approach_speed,
		"peak_predicted_local_normal_load_n": peak_predicted_load,
		"initial_right_contact_count": initial_right_contact_count,
		"non_distal_contact_count": non_distal_contact_count,
		"support_interval_before_m": support_interval_before,
		"support_interval_after_m": support_interval_after,
		"measured_support_improvement_m": measured_support_improvement,
		"maximum_horizontal_position_error_m": maximum_horizontal_position_error,
		"maximum_horizontal_speed_m_s": maximum_horizontal_speed,
		"maximum_commanded_tangent_n": maximum_commanded_tangent,
		"maximum_applied_torque_nm": maximum_applied_torque,
		"maximum_pairing_residual_nm": maximum_pairing_residual,
		"actuator_saturation_count": actuator_saturation_count,
		"allocator_clamp_count": allocator_clamp_count,
		"maximum_normal_load_rate_n_s": maximum_normal_load_rate,
		"post_impulse_pitch_rate_rad_s": post_impulse_pitch_rate,
		"pitch_at_first_bearing_rad": pitch_at_first_bearing,
		"maximum_pitch_excursion_rad": maximum_pitch_excursion,
		"maximum_height_error_m": maximum_height_error,
		"post_stance_sample_count": post_stance_sample_count,
		"post_stance_bearing_loss_count": post_stance_bearing_loss_count,
		"maximum_post_stance_pitch_error_rad": maximum_post_stance_pitch_error,
		"maximum_post_stance_pitch_rate_rad_s": maximum_post_stance_pitch_rate,
		"maximum_post_stance_height_error_m": maximum_post_stance_height_error,
		"normal_load_rate_is_bearing_command_only": true,
		"final_pitch_rad": final_pitch,
		"final_pitch_rate_rad_s": final_pitch_rate,
		"final_height_error_m": final_height_error,
		"target_arrival_used_for_phase_transition": target_arrival_used_for_transition,
		"local_load_is_generalized_per_foot_allocation":
		local_load_is_generalized_per_foot_allocation,
		"root_rescue_operation_count": 0,
		"foot_pin_operation_count": 0,
		"pose_teleport_operation_count": 0,
		"automatic_creature_guidance_operation_count": 0,
		"per_contact_commands_are_measurements": false,
		"free_3d_stance_established": false,
	}
	viewport.queue_free()
	await tree.process_frame
	await tree.physics_frame
	return {"ok": true, "summary": summary}


static func _catch_leg_plans(
	tick: int,
	root: RigidBody3D,
	leg: Dictionary,
	normal_load: float,
	tangent_load: float,
	configuration: Dictionary,
	actuator_spec: Dictionary,
	gravity: float
) -> Dictionary:
	var link_1: RigidBody3D = leg["link_1"]
	var link_2: RigidBody3D = leg["link_2"]
	var q1_absolute := _absolute_link_angle(link_1)
	var q2_absolute := _absolute_link_angle(link_2)
	var root_pitch := _root_pitch(root)
	var q1_local := wrapf(q1_absolute - root_pitch, -PI, PI)
	var q2_local := wrapf(q2_absolute - q1_absolute, -PI, PI)
	var q1_rate := (link_1.angular_velocity - root.angular_velocity).dot(PITCH_AXIS)
	var q2_rate := (link_2.angular_velocity - link_1.angular_velocity).dot(PITCH_AXIS)
	var mapping_result := (
		SagittalForceMapScript
		. map(
			{
				"schema_version": "sagittal_contact_force_map_request_v1",
				"joint_1_angle_rad": q1_absolute,
				"joint_2_angle_rad": q2_local,
				"link_1_length_m": float(configuration["link_length_m"]),
				"link_2_length_m": float(configuration["link_length_m"]),
				"carriage_mass_kg": float(configuration["root_mass_kg"]) * 0.5,
				"link_1_mass_kg": float(configuration["link_mass_kg"]),
				"link_2_mass_kg": float(configuration["link_mass_kg"]),
				"gravity_m_s2": gravity,
				"tangent_force_n": tangent_load,
				"normal_force_n": normal_load,
			}
		)
	)
	if not bool(mapping_result.get("ok", false)):
		return {"ok": false, "failure_code": "BR10_CATCH_FORCE_MAP_INVALID"}
	var mapping: Dictionary = mapping_result["mapping"]
	var feedforward_1 := float(mapping["joint_1_feedforward_nm"])
	var feedforward_2 := float(mapping["joint_2_feedforward_nm"])
	var request_1 := (
		feedforward_1
		- (
			float(configuration["joint_position_gain_nm_rad"])
			* (q1_local - float(leg["target_q1_rad"]))
		)
		- float(configuration["joint_velocity_gain_nm_s_rad"]) * q1_rate
	)
	var request_2 := (
		feedforward_2
		- (
			float(configuration["joint_position_gain_nm_rad"])
			* (q2_local - float(leg["target_q2_rad"]))
		)
		- float(configuration["joint_velocity_gain_nm_s_rad"]) * q2_rate
	)
	var hip_position := root.global_position + root.global_basis.x * float(leg["hip_local_x_m"])
	var knee_position := (
		link_1.global_position
		+ 0.5 * float(configuration["link_length_m"]) * link_1.global_basis.x.normalized()
	)
	var plan_1 := _plan(
		tick,
		"br10_%s_hip" % String(leg["label"]),
		ROOT_ID,
		String(leg["link_1_id"]),
		hip_position,
		q1_rate,
		request_1,
		feedforward_1,
		float(leg["previous_active_1"]),
		float(leg["previous_activation_1"]),
		configuration,
		actuator_spec
	)
	var plan_2 := _plan(
		tick,
		"br10_%s_knee" % String(leg["label"]),
		String(leg["link_1_id"]),
		String(leg["link_2_id"]),
		knee_position,
		q2_rate,
		request_2,
		feedforward_2,
		float(leg["previous_active_2"]),
		float(leg["previous_activation_2"]),
		configuration,
		actuator_spec
	)
	if not bool(plan_1.get("ok", false)) or not bool(plan_2.get("ok", false)):
		return {"ok": false, "failure_code": "BR10_CATCH_ACTUATOR_PLAN_INVALID"}
	plan_1["leg_state"] = leg
	plan_1["state_slot"] = 1
	plan_2["leg_state"] = leg
	plan_2["state_slot"] = 2
	return {"ok": true, "plans": [plan_1, plan_2]}


static func _world_target_ik(
	root: RigidBody3D, target_world: Vector3, link_length_m: float
) -> Dictionary:
	var local := root.global_basis.inverse() * (target_world - root.global_position)
	var down := -local.y
	var distance := Vector2(local.x, down).length()
	if (
		not local.is_finite()
		or not is_finite(distance)
		or distance <= 1.0e-6
		or distance >= 2.0 * link_length_m
	):
		return {"ok": false, "failure_code": "BR10_WORLD_TARGET_UNREACHABLE"}
	var phi := atan2(local.x, down)
	var delta := acos(clampf(distance / (2.0 * link_length_m), -1.0, 1.0))
	return {
		"ok": true,
		"q1_rad": phi + delta,
		"q2_rad": -2.0 * delta,
	}


static func _rate_limit_normal_pair(
	previous_left_n: float,
	previous_right_n: float,
	target_left_n: float,
	target_right_n: float,
	maximum_step_n: float,
	minimum_normal_n: float,
	maximum_normal_n: float
) -> Dictionary:
	var target_total := target_left_n + target_right_n
	var minimum_left := maxf(minimum_normal_n, previous_left_n - maximum_step_n)
	minimum_left = maxf(minimum_left, target_total - maximum_normal_n)
	minimum_left = maxf(minimum_left, target_total - (previous_right_n + maximum_step_n))
	var maximum_left := minf(maximum_normal_n, previous_left_n + maximum_step_n)
	maximum_left = minf(maximum_left, target_total - minimum_normal_n)
	maximum_left = minf(maximum_left, target_total - (previous_right_n - maximum_step_n))
	if minimum_left > maximum_left + 1.0e-9:
		return {"ok": false, "failure_code": "BR10_NORMAL_RATE_PAIR_INFEASIBLE"}
	var left := clampf(target_left_n, minimum_left, maximum_left)
	var right := target_total - left
	if (
		absf(left - previous_left_n) > maximum_step_n + 1.0e-7
		or absf(right - previous_right_n) > maximum_step_n + 1.0e-7
		or left < minimum_normal_n - 1.0e-7
		or right < minimum_normal_n - 1.0e-7
		or left > maximum_normal_n + 1.0e-7
		or right > maximum_normal_n + 1.0e-7
	):
		return {"ok": false, "failure_code": "BR10_NORMAL_RATE_PAIR_POSTCONDITION_FAILED"}
	return {
		"ok": true,
		"left_normal_n": left,
		"right_normal_n": right,
	}


static func _clamp_two_contact_moment(
	desired_moment_nm: float,
	desired_vertical_n: float,
	left_support_x_m: float,
	right_support_x_m: float,
	minimum_normal_n: float,
	maximum_normal_n: float
) -> Dictionary:
	var minimum_left := maxf(minimum_normal_n, desired_vertical_n - maximum_normal_n)
	var maximum_left := minf(maximum_normal_n, desired_vertical_n - minimum_normal_n)
	if minimum_left > maximum_left or absf(left_support_x_m - right_support_x_m) <= 1.0e-6:
		return {"ok": false, "failure_code": "BR10_MOMENT_INTERVAL_INVALID"}
	var moment_at_minimum_left := (
		left_support_x_m * minimum_left + right_support_x_m * (desired_vertical_n - minimum_left)
	)
	var moment_at_maximum_left := (
		left_support_x_m * maximum_left + right_support_x_m * (desired_vertical_n - maximum_left)
	)
	var minimum_moment := minf(moment_at_minimum_left, moment_at_maximum_left)
	var maximum_moment := maxf(moment_at_minimum_left, moment_at_maximum_left)
	var applied := clampf(desired_moment_nm, minimum_moment, maximum_moment)
	return {
		"ok": true,
		"moment_nm": applied,
		"clamped": absf(applied - desired_moment_nm) > 1.0e-9,
		"minimum_moment_nm": minimum_moment,
		"maximum_moment_nm": maximum_moment,
	}


static func _receipts_match(receipts: Array, payload_hash: String, operations: Array) -> bool:
	if receipts.size() != operations.size():
		return false
	var expected: Dictionary = {}
	for operation_value in operations:
		var operation: Dictionary = operation_value
		expected[String(operation["operation_id"])] = String(operation["body_id"])
	for receipt_value in receipts:
		var receipt: Dictionary = receipt_value
		if (
			String(receipt.get("status", "")) != "call_returned"
			or String(receipt.get("source_payload_sha256", "")) != payload_hash
			or not expected.has(String(receipt.get("operation_id", "")))
			or (
				expected[String(receipt["operation_id"])]
				!= String(receipt.get("target_body_id", ""))
			)
		):
			return false
	return true
