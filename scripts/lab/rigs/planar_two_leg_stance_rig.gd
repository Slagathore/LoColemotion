class_name LabPlanarTwoLegStanceRig
extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## BR7 live two-leg sagittal stance fixture.
##
## The Generic6DOF guide releases in-plane X/Y translation and pitch about Z.
## It locks only out-of-plane translation, roll, and yaw. The guide has no
## motor or spring. Four explicit hinge actuators produce all controlled
## support through two ordinary distal sphere contacts.

const ActuationExecutorScript := preload("res://scripts/lab/actuation_executor.gd")
const BodyWrenchScript := preload("res://scripts/lab/mechanics/body_wrench.gd")
const CommandLedgerScript := preload("res://scripts/lab/command_ledger.gd")
const ForceMapScript := preload("res://scripts/lab/mechanics/force_to_joint_map.gd")
const JointActuatorScript := preload("res://scripts/lab/mechanics/joint_actuator.gd")
const AllocatorScript := preload("res://scripts/lab/mechanics/planar_contact_allocator.gd")
const ReconstructorScript := preload(
	"res://scripts/lab/mechanics/external_contact_impulse_reconstructor.gd"
)
const SupervisorScript := preload("res://scripts/lab/mechanics/planar_support_supervisor.gd")
const ReceiptSinkScript := preload("res://scripts/lab/records/execution_receipt.gd")

const LAB_COLLISION_LAYER := 1 << 20
const PITCH_AXIS := Vector3.BACK
const ROOT_ID := "br7_planar_root"
const ROOT_SIZE_M := Vector3(0.50, 0.16, 0.20)
const LINK_WIDTH_M := 0.05
const LINK_DEPTH_M := 0.08


func run(tree: SceneTree, configuration: Dictionary, actuator_spec: Dictionary) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "BR7_PlanarTwoLegStance"
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var world := Node3D.new()
	world.name = "BR7_PlanarTwoLegStanceWorld"
	var baseline := float(configuration["baseline_height_m"])
	var foot_radius := float(configuration["foot_radius_m"])
	var link_length := float(configuration["link_length_m"])
	var cosine := (baseline - foot_radius) / (2.0 * link_length)
	if cosine <= 0.0 or cosine > 1.0:
		viewport.queue_free()
		await tree.physics_frame
		return {"ok": false, "failure_code": "PLANAR_STANCE_INITIAL_IK_INVALID"}
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
	var step_s := 1.0 / float(configuration["physics_hz"])
	var total_ticks := (
		int(configuration["support_loss_tick"]) + int(configuration["post_loss_ticks"])
	)
	var receipt_sink = ReceiptSinkScript.new("br7_planar_two_leg_stance")
	var supervisor = SupervisorScript.new()
	var fixture_complete := true
	var all_receipts_complete := true
	var maximum_pairing_residual := 0.0
	var maximum_requested_torque := 0.0
	var maximum_applied_torque := 0.0
	var actuator_saturation_count := 0
	var allocator_infeasible_before_loss_count := 0
	var allocation_maximum_force_residual := 0.0
	var allocation_maximum_moment_residual := 0.0
	var controller_wrench_saturation_count := 0
	var static_height_error := 0.0
	var static_pitch_error := 0.0
	var static_vertical_velocity := 0.0
	var static_pitch_rate := 0.0
	var static_support_error := 0.0
	var static_realized_vertical_wrench_residual := 0.0
	var static_realized_pitch_wrench_residual := 0.0
	var left_contact_samples := 0
	var right_contact_samples := 0
	var contact_measurement_samples := 0
	var disturbance_count := 0
	var maximum_pitch_excursion := 0.0
	var signed_pitch_excursion := 0.0
	var recovery_dwell := 0
	var recovery_tick := -1
	var support_loss_event_count := 0
	var support_loss_event_tick := -1
	var support_loss_response := ""
	var controlled_stop := false
	var executed_ticks := 0
	var right_collision_disabled := false
	var last_infeasible_reasons: Array = []
	var last_infeasible_tick := -1
	var last_infeasible_desired_vertical_n := 0.0
	var last_infeasible_desired_moment_nm := 0.0
	var last_infeasible_root_height_m := baseline
	var last_infeasible_root_pitch_rad := 0.0
	var last_infeasible_root_vertical_velocity_m_s := 0.0
	var last_infeasible_root_pitch_rate_rad_s := 0.0
	for tick in total_ticks:
		if tick == int(configuration["support_loss_tick"]):
			var right_link_2: RigidBody3D = right["link_2"]
			right_link_2.collision_layer = 0
			right_link_2.collision_mask = 0
			right_collision_disabled = true
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
		var raw_desired_vertical := (
			total_mass * gravity
			+ float(configuration["height_position_gain_n_m"]) * (baseline - root.global_position.y)
			- float(configuration["height_velocity_gain_n_s_m"]) * root.linear_velocity.y
		)
		var raw_desired_moment := (
			-float(configuration["pitch_position_gain_nm_rad"]) * pitch
			- float(configuration["pitch_velocity_gain_nm_s_rad"]) * pitch_rate
		)
		var maximum_normal := float(configuration["maximum_contact_normal_n"])
		var reserve := float(configuration["controller_feasibility_reserve_fraction"])
		var desired_vertical := clampf(
			raw_desired_vertical, (1.0 - reserve) * total_mass * gravity, 2.0 * maximum_normal
		)
		var left_support_x := left_foot.x - com.x
		var right_support_x := right_foot.x - com.x
		var span := right_support_x - left_support_x
		var minimum_right_normal := maxf(0.0, desired_vertical - maximum_normal)
		var maximum_right_normal := minf(maximum_normal, desired_vertical)
		var exact_minimum_moment := left_support_x * desired_vertical + span * minimum_right_normal
		var exact_maximum_moment := left_support_x * desired_vertical + span * maximum_right_normal
		var moment_midpoint := 0.5 * (exact_minimum_moment + exact_maximum_moment)
		var moment_half_range := 0.5 * (exact_maximum_moment - exact_minimum_moment) * reserve
		var desired_moment := clampf(
			raw_desired_moment,
			moment_midpoint - moment_half_range,
			moment_midpoint + moment_half_range
		)
		if (
			not is_equal_approx(desired_vertical, raw_desired_vertical)
			or not is_equal_approx(desired_moment, raw_desired_moment)
		):
			controller_wrench_saturation_count += 1
		var controller_left_bearing := true
		var controller_right_bearing := true
		if right_collision_disabled and not right_bearing:
			controller_right_bearing = false
		var allocation_result := (
			AllocatorScript
			. allocate(
				{
					"schema_version": "planar_contact_allocation_request_v1",
					"tick": tick,
					"desired_force_x_n": 0.0,
					"desired_force_y_n": desired_vertical,
					"desired_moment_z_nm": desired_moment,
					"left_support_x_m": left_support_x,
					"right_support_x_m": right_support_x,
					"left_bearing": controller_left_bearing,
					"right_bearing": controller_right_bearing,
					"friction_coefficient": float(configuration["friction_coefficient"]),
					"minimum_normal_n": 0.0,
					"maximum_normal_n": maximum_normal,
					"feasibility_tolerance": 1.0e-8,
				}
			)
		)
		if not bool(allocation_result.get("ok", false)):
			fixture_complete = false
			break
		var allocation: Dictionary = allocation_result["allocation"]
		if not bool(allocation["feasible"]):
			last_infeasible_reasons = allocation["infeasibility_reasons"]
			last_infeasible_tick = tick
			last_infeasible_desired_vertical_n = desired_vertical
			last_infeasible_desired_moment_nm = desired_moment
			last_infeasible_root_height_m = root.global_position.y
			last_infeasible_root_pitch_rad = pitch
			last_infeasible_root_vertical_velocity_m_s = root.linear_velocity.y
			last_infeasible_root_pitch_rate_rad_s = pitch_rate
		var supervisor_state := supervisor.update(
			tick, left_bearing, right_bearing, bool(allocation["feasible"])
		)
		for event_value in supervisor_state["events"]:
			var event: Dictionary = event_value
			if String(event["event"]) == "SUPPORT_LOST":
				support_loss_event_count += 1
				support_loss_event_tick = tick
				support_loss_response = String(supervisor_state["response"])
		if tick >= int(configuration["support_loss_tick"]) and not bool(allocation["feasible"]):
			controlled_stop = true
			executed_ticks = tick
			break
		if not bool(allocation["feasible"]):
			allocator_infeasible_before_loss_count += 1
			fixture_complete = false
			break
		var force_residual: Array = allocation["force_residual_n"]
		allocation_maximum_force_residual = maxf(
			allocation_maximum_force_residual,
			Vector2(float(force_residual[0]), float(force_residual[1])).length()
		)
		allocation_maximum_moment_residual = maxf(
			allocation_maximum_moment_residual, absf(float(allocation["moment_residual_z_nm"]))
		)
		var plans: Array = []
		var left_plans := _leg_plans(
			tick,
			root,
			left,
			float(allocation["left"]["normal_force_n"]),
			configuration,
			actuator_spec,
			gravity,
			left_foot
		)
		var right_plans := _leg_plans(
			tick,
			root,
			right,
			float(allocation["right"]["normal_force_n"]),
			configuration,
			actuator_spec,
			gravity,
			right_foot
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
					"run_id": "br7_planar_two_leg_stance",
					"command_id": tick,
					"source_frame_id": tick,
					"applied_transition": [tick, tick + 1],
					"mode": "BR7_PLANAR_STANCE",
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
			var plan: Dictionary = plan_value
			operations.append_array(plan["command"]["planned_application_operations"])
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
		var reconstructed_support := float(
			reconstruction["reconstructed_step_average_normal_load_n"]
		)
		var reconstructed_moment := (
			(after_angular - before_angular - known_angular_impulse) / step_s
		)
		for plan_value in plans:
			var plan: Dictionary = plan_value
			var resolution: Dictionary = plan["resolution"]
			maximum_pairing_residual = maxf(
				maximum_pairing_residual,
				float((plan["command"]["diagnostics"] as Dictionary)["pairing_residual_nm"])
			)
			maximum_requested_torque = maxf(
				maximum_requested_torque, absf(float(resolution["requested_active_nm"]))
			)
			maximum_applied_torque = maxf(
				maximum_applied_torque, absf(float(resolution["applied_total_nm"]))
			)
			if _resolution_saturated(resolution):
				actuator_saturation_count += 1
			_update_leg_state(plan)
		if (
			tick >= int(configuration["static_measure_start_tick"])
			and tick < int(configuration["disturbance_tick"])
		):
			contact_measurement_samples += 1
			left_contact_samples += int(left_bearing)
			right_contact_samples += int(right_bearing)
			static_height_error = maxf(static_height_error, absf(root.global_position.y - baseline))
			static_pitch_error = maxf(static_pitch_error, absf(_root_pitch(root)))
			static_vertical_velocity = maxf(static_vertical_velocity, absf(root.linear_velocity.y))
			static_pitch_rate = maxf(static_pitch_rate, absf(root.angular_velocity.dot(PITCH_AXIS)))
			static_support_error = maxf(
				static_support_error, absf(reconstructed_support - total_mass * gravity)
			)
			static_realized_vertical_wrench_residual = maxf(
				static_realized_vertical_wrench_residual,
				absf(reconstructed_support - desired_vertical)
			)
			static_realized_pitch_wrench_residual = maxf(
				static_realized_pitch_wrench_residual, absf(reconstructed_moment - desired_moment)
			)
		if tick >= int(configuration["disturbance_tick"]):
			var current_pitch := _root_pitch(root)
			if absf(current_pitch) > maximum_pitch_excursion:
				maximum_pitch_excursion = absf(current_pitch)
				signed_pitch_excursion = current_pitch
			var recovered := (
				absf(current_pitch) <= float(configuration["recovery_pitch_error_rad"])
				and (
					absf(root.angular_velocity.dot(PITCH_AXIS))
					<= float(configuration["recovery_pitch_rate_rad_s"])
				)
				and (
					absf(root.global_position.y - baseline)
					<= float(configuration["recovery_height_error_m"])
				)
			)
			recovery_dwell = recovery_dwell + 1 if recovered else 0
			if recovery_tick < 0 and recovery_dwell >= int(configuration["recovery_dwell_ticks"]):
				recovery_tick = tick - int(configuration["disturbance_tick"]) + 1
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
			"fixture_complete": fixture_complete,
			"executed_ticks": executed_ticks,
			"planar_guide_exact": planar_guide_exact,
			"hinges_exact": hinges_exact,
			"all_receipts_complete": all_receipts_complete,
			"maximum_pairing_residual_nm": maximum_pairing_residual,
			"maximum_requested_torque_nm": maximum_requested_torque,
			"maximum_applied_torque_nm": maximum_applied_torque,
			"actuator_saturation_count": actuator_saturation_count,
			"allocator_infeasible_before_loss_count": allocator_infeasible_before_loss_count,
			"allocation_maximum_force_residual_n": allocation_maximum_force_residual,
			"allocation_maximum_moment_residual_nm": allocation_maximum_moment_residual,
			"controller_wrench_saturation_count": controller_wrench_saturation_count,
			"static_maximum_height_error_m": static_height_error,
			"static_maximum_pitch_error_rad": static_pitch_error,
			"static_maximum_vertical_velocity_m_s": static_vertical_velocity,
			"static_maximum_pitch_rate_rad_s": static_pitch_rate,
			"static_maximum_support_error_n": static_support_error,
			"static_maximum_realized_vertical_wrench_residual_n":
			static_realized_vertical_wrench_residual,
			"static_maximum_realized_pitch_wrench_residual_nm":
			static_realized_pitch_wrench_residual,
			"left_contact_fraction":
			float(left_contact_samples) / float(maxi(contact_measurement_samples, 1)),
			"right_contact_fraction":
			float(right_contact_samples) / float(maxi(contact_measurement_samples, 1)),
			"disturbance_operation_count": disturbance_count,
			"maximum_pitch_excursion_rad": maximum_pitch_excursion,
			"signed_pitch_excursion_rad": signed_pitch_excursion,
			"disturbance_recovered": recovery_tick >= 0,
			"disturbance_recovery_ticks": maxi(recovery_tick, 0),
			"support_loss_event_count": support_loss_event_count,
			"support_loss_event_tick": support_loss_event_tick,
			"support_loss_response": support_loss_response,
			"controlled_stop": controlled_stop,
			"last_infeasible_reasons": last_infeasible_reasons,
			"last_infeasible_tick": last_infeasible_tick,
			"last_infeasible_desired_vertical_n": last_infeasible_desired_vertical_n,
			"last_infeasible_desired_moment_nm": last_infeasible_desired_moment_nm,
			"last_infeasible_root_height_m": last_infeasible_root_height_m,
			"last_infeasible_root_pitch_rad": last_infeasible_root_pitch_rad,
			"last_infeasible_root_vertical_velocity_m_s":
			last_infeasible_root_vertical_velocity_m_s,
			"last_infeasible_root_pitch_rate_rad_s": last_infeasible_root_pitch_rate_rad_s,
			"root_rescue_operation_count": 0,
			"foot_pin_operation_count": 0,
			"passive_operation_count": 0,
			"per_contact_commands_are_measurements": false,
			"per_foot_measured_load_allocation_available": false,
		},
	}


static func _build_leg(
	label: String, hip: Vector3, signed_alpha: float, configuration: Dictionary
) -> Dictionary:
	var length := float(configuration["link_length_m"])
	var mass := float(configuration["link_mass_kg"])
	var radius := float(configuration["foot_radius_m"])
	var q1 := signed_alpha
	var q2 := -2.0 * signed_alpha
	var absolute_2 := q1 + q2
	var direction_1 := Vector3(sin(q1), -cos(q1), 0.0)
	var direction_2 := Vector3(sin(absolute_2), -cos(absolute_2), 0.0)
	var knee := hip + length * direction_1
	var link_1_id := "br7_%s_link_1" % label
	var link_2_id := "br7_%s_link_2" % label
	var link_1 := _build_link(
		link_1_id, hip + 0.5 * length * direction_1, q1, mass, length, false, radius
	)
	var link_2 := _build_link(
		link_2_id, knee + 0.5 * length * direction_2, absolute_2, mass, length, true, radius
	)
	return {
		"label": label,
		"hip_local_x_m": hip.x,
		"target_q1_rad": q1,
		"target_q2_rad": q2,
		"initial_hip": hip,
		"initial_knee": knee,
		"initial_link_1_position": link_1.position,
		"initial_link_2_position": link_2.position,
		"link_1_id": link_1_id,
		"link_2_id": link_2_id,
		"link_1": link_1,
		"link_2": link_2,
		"hip_hinge": _build_hinge("br7_%s_hip" % label, hip),
		"knee_hinge": _build_hinge("br7_%s_knee" % label, knee),
		"previous_active_1": 0.0,
		"previous_active_2": 0.0,
		"previous_activation_1": 1.0,
		"previous_activation_2": 1.0,
	}


static func _leg_plans(
	tick: int,
	root: RigidBody3D,
	leg: Dictionary,
	normal_load: float,
	configuration: Dictionary,
	actuator_spec: Dictionary,
	gravity: float,
	foot_position: Vector3
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
	var wrench_result := (
		BodyWrenchScript
		. compile(
			{
				"schema_version": "body_wrench_v1",
				"wrench_id": "br7.%s.tick_%06d" % [String(leg["label"]), tick],
				"source_id": "br7.planar_allocator",
				"frame_id": "world",
				"application_point_world_m": [foot_position.x, foot_position.y, foot_position.z],
				"force_world_n": [0.0, normal_load, 0.0],
				"moment_world_nm": [0.0, 0.0, 0.0],
			}
		)
	)
	if not bool(wrench_result.get("ok", false)):
		return {"ok": false, "failure_code": "PLANAR_STANCE_WRENCH_INVALID"}
	var mapping_result := (
		ForceMapScript
		. map(
			{
				"schema_version": "two_link_force_map_request_v1",
				"joint_1_angle_rad": q1_absolute,
				"joint_2_angle_rad": q2_local,
				"link_1_length_m": float(configuration["link_length_m"]),
				"link_2_length_m": float(configuration["link_length_m"]),
				"carriage_mass_kg": float(configuration["root_mass_kg"]) * 0.5,
				"link_1_mass_kg": float(configuration["link_mass_kg"]),
				"link_2_mass_kg": float(configuration["link_mass_kg"]),
				"gravity_m_s2": gravity,
				"wrench": wrench_result["wrench"],
			}
		)
	)
	if not bool(mapping_result.get("ok", false)):
		return {"ok": false, "failure_code": "PLANAR_STANCE_FORCE_MAP_INVALID"}
	var mapping: Dictionary = mapping_result["mapping"]
	var request_1 := (
		float(mapping["joint_1_feedforward_nm"])
		- (
			float(configuration["joint_position_gain_nm_rad"])
			* (q1_local - float(leg["target_q1_rad"]))
		)
		- float(configuration["joint_velocity_gain_nm_s_rad"]) * q1_rate
	)
	var request_2 := (
		float(mapping["joint_2_feedforward_nm"])
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
		"br7_%s_hip" % String(leg["label"]),
		ROOT_ID,
		String(leg["link_1_id"]),
		hip_position,
		q1_rate,
		request_1,
		float(mapping["joint_1_feedforward_nm"]),
		float(leg["previous_active_1"]),
		float(leg["previous_activation_1"]),
		configuration,
		actuator_spec
	)
	var plan_2 := _plan(
		tick,
		"br7_%s_knee" % String(leg["label"]),
		String(leg["link_1_id"]),
		String(leg["link_2_id"]),
		knee_position,
		q2_rate,
		request_2,
		float(mapping["joint_2_feedforward_nm"]),
		float(leg["previous_active_2"]),
		float(leg["previous_activation_2"]),
		configuration,
		actuator_spec
	)
	if not bool(plan_1.get("ok", false)) or not bool(plan_2.get("ok", false)):
		return {"ok": false, "failure_code": "PLANAR_STANCE_ACTUATOR_PLAN_INVALID"}
	plan_1["leg_state"] = leg
	plan_1["state_slot"] = 1
	plan_2["leg_state"] = leg
	plan_2["state_slot"] = 2
	return {"ok": true, "plans": [plan_1, plan_2]}


static func _plan(
	tick: int,
	joint_id: String,
	parent_id: String,
	child_id: String,
	pivot: Vector3,
	rate: float,
	requested: float,
	feedforward: float,
	previous_active: float,
	previous_activation: float,
	configuration: Dictionary,
	actuator_spec: Dictionary
) -> Dictionary:
	return (
		JointActuatorScript
		. resolve_and_plan(
			{
				"schema_version": "joint_actuator_input_v1",
				"tick": tick,
				"joint_id": joint_id,
				"parent_body_id": parent_id,
				"child_body_id": child_id,
				"source_id": "br7_planar_stance",
				"behavior_state": "PLANAR_STANCE",
				"axis_world": PITCH_AXIS,
				"pivot_world": pivot,
				"angular_velocity_rad_s": rate,
				"active_components":
				{
					"br7.force_map_feedforward": feedforward,
					"br7.joint_tracking": requested - feedforward,
				},
				"passive_components": {},
				"previous_active_nm": previous_active,
				"previous_activation": previous_activation,
				"step_s": 1.0 / float(configuration["physics_hz"]),
			},
			actuator_spec
		)
	)


static func _update_leg_state(plan: Dictionary) -> void:
	var state: Dictionary = plan["leg_state"]
	var resolution: Dictionary = plan["resolution"]
	if int(plan["state_slot"]) == 1:
		state["previous_active_1"] = float(resolution["applied_active_nm"])
		state["previous_activation_1"] = float(resolution["activation_next"])
	else:
		state["previous_active_2"] = float(resolution["applied_active_nm"])
		state["previous_activation_2"] = float(resolution["activation_next"])


static func _reset_root_and_leg(root: RigidBody3D, leg: Dictionary, root_position: Vector3) -> void:
	root.global_position = root_position
	root.quaternion = Quaternion.IDENTITY
	var link_1: RigidBody3D = leg["link_1"]
	var link_2: RigidBody3D = leg["link_2"]
	link_1.global_position = leg["initial_link_1_position"]
	link_1.rotation = Vector3(0.0, 0.0, float(leg["target_q1_rad"]) - PI * 0.5)
	var absolute_2 := float(leg["target_q1_rad"]) + float(leg["target_q2_rad"])
	link_2.global_position = leg["initial_link_2_position"]
	link_2.rotation = Vector3(0.0, 0.0, absolute_2 - PI * 0.5)
	for body in [root, link_1, link_2]:
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = false


static func _build_root(position: Vector3, mass_kg: float) -> RigidBody3D:
	var body := _body(ROOT_ID, position, mass_kg)
	body.collision_layer = 0
	body.collision_mask = 0
	body.inertia = Vector3(
		mass_kg * (ROOT_SIZE_M.y * ROOT_SIZE_M.y + ROOT_SIZE_M.z * ROOT_SIZE_M.z) / 12.0,
		mass_kg * (ROOT_SIZE_M.x * ROOT_SIZE_M.x + ROOT_SIZE_M.z * ROOT_SIZE_M.z) / 12.0,
		mass_kg * (ROOT_SIZE_M.x * ROOT_SIZE_M.x + ROOT_SIZE_M.y * ROOT_SIZE_M.y) / 12.0
	)
	_add_box(body, ROOT_SIZE_M, Vector3.ZERO)
	return body


static func _build_link(
	body_id: String,
	position: Vector3,
	absolute_angle: float,
	mass_kg: float,
	length_m: float,
	has_foot: bool,
	foot_radius_m: float
) -> RigidBody3D:
	var body := _body(body_id, position, mass_kg)
	body.rotation = Vector3(0.0, 0.0, absolute_angle - PI * 0.5)
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector3.ZERO
	body.inertia = Vector3(
		mass_kg * (LINK_WIDTH_M * LINK_WIDTH_M + LINK_DEPTH_M * LINK_DEPTH_M) / 12.0,
		mass_kg * (length_m * length_m + LINK_DEPTH_M * LINK_DEPTH_M) / 12.0,
		mass_kg * (length_m * length_m + LINK_WIDTH_M * LINK_WIDTH_M) / 12.0
	)
	body.collision_layer = LAB_COLLISION_LAYER if has_foot else 0
	body.collision_mask = LAB_COLLISION_LAYER if has_foot else 0
	body.contact_monitor = has_foot
	body.max_contacts_reported = 16 if has_foot else 0
	var collision_length := length_m - 2.0 * foot_radius_m if has_foot else length_m
	_add_box(body, Vector3(collision_length, LINK_WIDTH_M, LINK_DEPTH_M), Vector3.ZERO)
	if has_foot:
		var foot := CollisionShape3D.new()
		foot.name = "ordinary_distal_sphere"
		foot.position = Vector3(length_m * 0.5, 0.0, 0.0)
		var sphere := SphereShape3D.new()
		sphere.radius = foot_radius_m
		foot.shape = sphere
		body.add_child(foot)
	return body


static func _body(body_id: String, position: Vector3, mass_kg: float) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = body_id
	body.position = position
	body.mass = mass_kg
	body.gravity_scale = 1.0
	body.can_sleep = false
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.freeze = true
	return body


static func _build_anchor(position: Vector3) -> StaticBody3D:
	var anchor := StaticBody3D.new()
	anchor.name = "br7_planar_guide_anchor"
	anchor.position = position
	anchor.collision_layer = 0
	anchor.collision_mask = 0
	return anchor


static func _build_floor(friction: float) -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "br7_floor"
	floor.position = Vector3(0.0, -0.5, 0.0)
	floor.collision_layer = LAB_COLLISION_LAYER
	floor.collision_mask = LAB_COLLISION_LAYER
	_add_box(floor, Vector3(8.0, 1.0, 8.0), Vector3.ZERO)
	var material := PhysicsMaterial.new()
	material.friction = friction
	material.bounce = 0.0
	floor.physics_material_override = material
	return floor


static func _build_planar_guide(position: Vector3) -> Generic6DOFJoint3D:
	var guide := Generic6DOFJoint3D.new()
	guide.name = "br7_planar_guide"
	guide.position = position
	for axis in ["x", "y", "z"]:
		guide.set("linear_limit_%s/enabled" % axis, axis == "z")
		guide.set("linear_limit_%s/lower_distance" % axis, 0.0)
		guide.set("linear_limit_%s/upper_distance" % axis, 0.0)
		guide.set("linear_motor_%s/enabled" % axis, false)
		guide.set("linear_spring_%s/enabled" % axis, false)
		guide.set("angular_limit_%s/enabled" % axis, axis != "z")
		guide.set("angular_limit_%s/lower_angle" % axis, 0.0)
		guide.set("angular_limit_%s/upper_angle" % axis, 0.0)
		guide.set("angular_motor_%s/enabled" % axis, false)
		guide.set("angular_spring_%s/enabled" % axis, false)
	return guide


static func _build_hinge(name_value: String, position: Vector3) -> HingeJoint3D:
	var hinge := HingeJoint3D.new()
	hinge.name = name_value
	hinge.position = position
	hinge.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
	hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, false)
	return hinge


static func _planar_guide_exact(guide: Generic6DOFJoint3D) -> bool:
	if (
		bool(guide.get("linear_limit_x/enabled"))
		or bool(guide.get("linear_limit_y/enabled"))
		or not bool(guide.get("linear_limit_z/enabled"))
		or not bool(guide.get("angular_limit_x/enabled"))
		or not bool(guide.get("angular_limit_y/enabled"))
		or bool(guide.get("angular_limit_z/enabled"))
	):
		return false
	for axis in ["x", "y", "z"]:
		if (
			bool(guide.get("linear_motor_%s/enabled" % axis))
			or bool(guide.get("linear_spring_%s/enabled" % axis))
			or bool(guide.get("angular_motor_%s/enabled" % axis))
			or bool(guide.get("angular_spring_%s/enabled" % axis))
		):
			return false
	return true


static func _hinge_exact(hinge: HingeJoint3D) -> bool:
	return (
		not hinge.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR)
		and not hinge.get_flag(HingeJoint3D.FLAG_USE_LIMIT)
	)


static func _absolute_link_angle(body: RigidBody3D) -> float:
	var direction := body.global_basis.x.normalized()
	return atan2(direction.x, -direction.y)


static func _root_pitch(root: RigidBody3D) -> float:
	var direction := root.global_basis.x.normalized()
	return atan2(direction.y, direction.x)


static func _foot_position(leg: Dictionary, link_length: float) -> Vector3:
	var link_2: RigidBody3D = leg["link_2"]
	return link_2.global_position + 0.5 * link_length * link_2.global_basis.x.normalized()


static func _system_com(bodies: Array[RigidBody3D]) -> Vector3:
	var mass := 0.0
	var weighted := Vector3.ZERO
	for body in bodies:
		mass += body.mass
		weighted += body.mass * body.global_position
	return weighted / mass


static func _angular_momentum_about_com(bodies: Array[RigidBody3D]) -> float:
	var com := _system_com(bodies)
	var result := 0.0
	for body in bodies:
		var orbital := (body.global_position - com).cross(body.mass * body.linear_velocity)
		result += orbital.dot(PITCH_AXIS)
		result += body.inertia.z * body.angular_velocity.dot(PITCH_AXIS)
	return result


static func _linear_samples(bodies: Array[RigidBody3D]) -> Array:
	var samples: Array = []
	for body in bodies:
		(
			samples
			. append(
				{
					"body_id": body.name,
					"mass_kg": body.mass,
					"linear_velocity_world_mps": body.linear_velocity,
				}
			)
		)
	return samples


static func _gravity_acceleration_world() -> Vector3:
	var magnitude := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var direction_value: Variant = ProjectSettings.get_setting(
		"physics/3d/default_gravity_vector", Vector3.DOWN
	)
	var direction := direction_value as Vector3 if direction_value is Vector3 else Vector3.DOWN
	return magnitude * direction.normalized()


static func _resolution_saturated(resolution: Dictionary) -> bool:
	return (
		bool(resolution["active_saturated"])
		or bool(resolution["torque_rate_limited"])
		or bool(resolution["structural_saturated"])
	)


static func _add_box(parent: CollisionObject3D, size: Vector3, local_position: Vector3) -> void:
	var collision := CollisionShape3D.new()
	collision.position = local_position
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	parent.add_child(collision)


static func _receipts_match(receipts: Array, payload_hash: String, operations: Array) -> bool:
	if receipts.size() != 8 or operations.size() != 8:
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
