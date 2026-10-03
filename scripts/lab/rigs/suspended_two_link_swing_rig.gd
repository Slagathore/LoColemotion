class_name LabSuspendedTwoLinkSwingRig
extends "res://scripts/lab/rigs/planar_two_leg_stance_rig.gd"
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## Live L4.2/L4.5 two-link target placement with a materially frozen root.


func run(tree: SceneTree, contract: Dictionary, actuator_spec: Dictionary) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "L4_2_L4_5_SuspendedSwing"
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var world := Node3D.new()
	world.name = "L4_2_L4_5_SuspendedSwingWorld"
	var root_position := Vector3(0.0, float(contract["root_height_m"]), 0.0)
	var root := _build_root(root_position, float(contract["root_mass_kg"]))
	var leg := _build_leg(
		"br10_swing",
		root_position,
		float(contract["initial_q1_rad"]),
		{
			"link_length_m": contract["link_length_m"],
			"link_mass_kg": contract["link_mass_kg"],
			"foot_radius_m": contract["foot_radius_m"],
		}
	)
	for node in [
		root,
		leg["link_1"],
		leg["link_2"],
		leg["hip_hinge"],
		leg["knee_hinge"],
	]:
		world.add_child(node)
	viewport.add_child(world)
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
	for body in [link_1, link_2]:
		(body as RigidBody3D).freeze = false
		(body as RigidBody3D).sleeping = false
	_reset_root_and_leg(root, leg, root_position)
	leg["target_q1_rad"] = float(contract["target_q1_rad"])
	leg["target_q2_rad"] = float(contract["target_q2_rad"])

	var bodies := {
		ROOT_ID: root,
		String(leg["link_1_id"]): link_1,
		String(leg["link_2_id"]): link_2,
	}
	var receipt_sink = ReceiptSinkScript.new("l4_2_l4_5_suspended_swing")
	var fixture_complete := true
	var all_receipts_complete := true
	var executed_ticks := 0
	var first_target_tick := -1
	var minimum_clearance := INF
	var maximum_applied_torque := 0.0
	var maximum_pairing_residual := 0.0
	var actuator_saturation_count := 0
	var contact_observation_count := 0
	var prior_foot := _foot_position(leg, float(contract["link_length_m"]))
	var final_foot_speed := 0.0
	var final_error := INF
	var target_local: Array = contract["target_foot_local_m"]
	var target_world := root_position + Vector3(float(target_local[0]), float(target_local[1]), 0.0)
	var step_s := 1.0 / float(contract["physics_hz"])

	for tick in int(contract["trial_ticks"]):
		var plans := _swing_plans(tick, root, leg, contract, actuator_spec)
		if not bool(plans.get("ok", false)):
			fixture_complete = false
			break
		var ledger = CommandLedgerScript.new()
		fixture_complete = ledger.begin_tick(tick) and fixture_complete
		for plan_value in plans["plans"]:
			fixture_complete = (
				ledger.queue_joint((plan_value as Dictionary)["command"]) and fixture_complete
			)
		var envelope := (
			ledger
			. seal(
				{
					"run_id": "l4_2_l4_5_suspended_swing",
					"command_id": tick,
					"source_frame_id": tick,
					"applied_transition": [tick, tick + 1],
					"mode": "L4_2_L4_5_SUSPENDED_SWING",
				}
			)
		)
		var before_receipts := receipt_sink.values().size()
		var execution := ActuationExecutorScript.apply_command_envelope(
			envelope, bodies, receipt_sink
		)
		await tree.physics_frame
		executed_ticks = tick + 1
		link_1.sleeping = false
		link_2.sleeping = false
		var receipts: Array = receipt_sink.values().slice(before_receipts)
		var operations: Array = []
		for plan_value in plans["plans"]:
			operations.append_array(
				(plan_value as Dictionary)["command"]["planned_application_operations"]
			)
		var receipts_match := _four_receipts_match(
			receipts, String(envelope["command_payload_sha256"]), operations
		)
		all_receipts_complete = all_receipts_complete and receipts_match
		fixture_complete = (
			fixture_complete
			and bool(execution.get("ok", false))
			and int(execution.get("applied_count", -1)) == 4
			and receipts_match
		)
		for plan_value in plans["plans"]:
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
		var foot := _foot_position(leg, float(contract["link_length_m"]))
		final_foot_speed = foot.distance_to(prior_foot) / step_s
		prior_foot = foot
		final_error = foot.distance_to(target_world)
		minimum_clearance = minf(minimum_clearance, foot.y - float(contract["foot_radius_m"]))
		contact_observation_count += (link_2 as RigidBody3D).get_colliding_bodies().size()
		if (
			first_target_tick < 0
			and final_error <= float(contract["target_position_tolerance_m"])
			and final_foot_speed <= float(contract["target_rate_tolerance_m_s"])
		):
			first_target_tick = tick + 1

	var summary := {
		"schema_version": "suspended_swing_summary_v1",
		"configuration_sha256": contract["configuration_sha256"],
		"actuator_spec_sha256": actuator_spec["spec_sha256"],
		"fixture_complete": fixture_complete,
		"executed_ticks": executed_ticks,
		"first_target_tick": first_target_tick,
		"final_target_error_m": final_error,
		"final_foot_speed_m_s": final_foot_speed,
		"minimum_clearance_m": minimum_clearance,
		"maximum_applied_torque_nm": maximum_applied_torque,
		"maximum_pairing_residual_nm": maximum_pairing_residual,
		"actuator_saturation_count": actuator_saturation_count,
		"contact_observation_count": contact_observation_count,
		"root_frozen": root.freeze,
		"motors_disabled":
		(
			not hip_hinge.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR)
			and not knee_hinge.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR)
		),
		"limits_disabled":
		(
			not hip_hinge.get_flag(HingeJoint3D.FLAG_USE_LIMIT)
			and not knee_hinge.get_flag(HingeJoint3D.FLAG_USE_LIMIT)
		),
		"all_receipts_complete": all_receipts_complete,
		"root_assist_operation_count": 0,
		"foot_pin_operation_count": 0,
		"pose_teleport_operation_count": 0,
		"automatic_creature_guidance_operation_count": 0,
	}
	viewport.queue_free()
	await tree.process_frame
	await tree.physics_frame
	return {"ok": true, "summary": summary}


static func _swing_plans(
	tick: int, root: RigidBody3D, leg: Dictionary, contract: Dictionary, actuator_spec: Dictionary
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
	var foot_position := _foot_position(leg, float(contract["link_length_m"]))
	var wrench_result := (
		BodyWrenchScript
		. compile(
			{
				"schema_version": "body_wrench_v1",
				"wrench_id": "br10.swing.tick_%06d" % tick,
				"source_id": "br10.suspended_swing_gravity_feedforward",
				"frame_id": "world",
				"application_point_world_m": [foot_position.x, foot_position.y, foot_position.z],
				"force_world_n": [0.0, 0.0, 0.0],
				"moment_world_nm": [0.0, 0.0, 0.0],
			}
		)
	)
	if not bool(wrench_result.get("ok", false)):
		return {"ok": false, "failure_code": "SUSPENDED_SWING_ZERO_WRENCH_INVALID"}
	var mapping_result := (
		ForceMapScript
		. map(
			{
				"schema_version": "two_link_force_map_request_v1",
				"joint_1_angle_rad": q1_absolute,
				"joint_2_angle_rad": q2_local,
				"link_1_length_m": float(contract["link_length_m"]),
				"link_2_length_m": float(contract["link_length_m"]),
				"carriage_mass_kg": float(contract["root_mass_kg"]),
				"link_1_mass_kg": float(contract["link_mass_kg"]),
				"link_2_mass_kg": float(contract["link_mass_kg"]),
				"gravity_m_s2": _gravity_acceleration_world().length(),
				"wrench": wrench_result["wrench"],
			}
		)
	)
	if not bool(mapping_result.get("ok", false)):
		return {"ok": false, "failure_code": "SUSPENDED_SWING_GRAVITY_MAP_INVALID"}
	var mapping: Dictionary = mapping_result["mapping"]
	var request_1 := (
		float(mapping["joint_1_link_gravity_nm"])
		- float(contract["joint_position_gain_nm_rad"]) * (q1_local - float(leg["target_q1_rad"]))
		- float(contract["joint_velocity_gain_nm_s_rad"]) * q1_rate
	)
	var request_2 := (
		float(mapping["joint_2_link_gravity_nm"])
		- float(contract["joint_position_gain_nm_rad"]) * (q2_local - float(leg["target_q2_rad"]))
		- float(contract["joint_velocity_gain_nm_s_rad"]) * q2_rate
	)
	var hip_position := root.global_position
	var knee_position := (
		link_1.global_position
		+ 0.5 * float(contract["link_length_m"]) * link_1.global_basis.x.normalized()
	)
	var plan_1 := _swing_plan(
		tick,
		"br10_swing_hip",
		ROOT_ID,
		String(leg["link_1_id"]),
		hip_position,
		q1_rate,
		request_1,
		float(leg["previous_active_1"]),
		float(leg["previous_activation_1"]),
		contract,
		actuator_spec
	)
	var plan_2 := _swing_plan(
		tick,
		"br10_swing_knee",
		String(leg["link_1_id"]),
		String(leg["link_2_id"]),
		knee_position,
		q2_rate,
		request_2,
		float(leg["previous_active_2"]),
		float(leg["previous_activation_2"]),
		contract,
		actuator_spec
	)
	if not bool(plan_1.get("ok", false)) or not bool(plan_2.get("ok", false)):
		return {"ok": false, "failure_code": "SUSPENDED_SWING_ACTUATOR_PLAN_INVALID"}
	plan_1["leg_state"] = leg
	plan_1["state_slot"] = 1
	plan_2["leg_state"] = leg
	plan_2["state_slot"] = 2
	return {"ok": true, "plans": [plan_1, plan_2]}


static func _swing_plan(
	tick: int,
	joint_id: String,
	parent_id: String,
	child_id: String,
	pivot: Vector3,
	rate: float,
	requested: float,
	previous_active: float,
	previous_activation: float,
	contract: Dictionary,
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
				"source_id": "l4_2_l4_5_suspended_swing",
				"behavior_state": "SWING",
				"axis_world": PITCH_AXIS,
				"pivot_world": pivot,
				"angular_velocity_rad_s": rate,
				"active_components": {"br10.swing_tracking": requested},
				"passive_components": {},
				"previous_active_nm": previous_active,
				"previous_activation": previous_activation,
				"step_s": 1.0 / float(contract["physics_hz"]),
			},
			actuator_spec
		)
	)


static func _four_receipts_match(receipts: Array, payload_hash: String, operations: Array) -> bool:
	if receipts.size() != 4 or operations.size() != 4:
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
