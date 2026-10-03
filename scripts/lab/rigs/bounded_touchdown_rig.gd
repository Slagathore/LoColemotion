class_name LabBoundedTouchdownRig
extends "res://scripts/lab/rigs/suspended_two_link_swing_rig.gd"
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## Live L4.6 fixed-root articulated touchdown on one semantic floor.

const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const CapacityScript := preload("res://scripts/lab/mechanics/contact_capacity.gd")
const CoordinatorScript := preload("res://scripts/lab/mechanics/catch_contact_phase_coordinator.gd")
const ObservedRigidBodyScript := preload("res://scripts/lab/mechanics/observed_rigid_body.gd")
const PressureObserverScript := preload("res://scripts/lab/mechanics/contact_pressure_observer.gd")

const FLOOR_ID := "br10_touchdown_floor"
const FLOOR_SHAPE_ID := "br10_touchdown_floor_shape"
const DISTAL_BODY_ID := "br10_touchdown_link_2"
const DISTAL_SHAPE_ID := "br10_touchdown_distal_sphere"
const LINK_SHAPE_ID := "br10_touchdown_link_box"


func run(tree: SceneTree, contract: Dictionary, actuator_spec: Dictionary) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "L4_6_BoundedTouchdown"
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var world := Node3D.new()
	world.name = "L4_6_BoundedTouchdownWorld"
	var clock = CaptureClockScript.new()
	var root_position := Vector3(0.0, float(contract["root_height_m"]), 0.0)
	var root := _build_root(root_position, float(contract["root_mass_kg"]))
	var leg_result := _build_touchdown_leg(root_position, contract, clock)
	if not bool(leg_result.get("ok", false)):
		viewport.queue_free()
		await tree.process_frame
		return leg_result
	var leg: Dictionary = leg_result["leg"]
	var floor := _build_semantic_floor()
	for node in [
		floor,
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
	var link_2: Variant = leg["link_2"]
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

	var coordinator = CoordinatorScript.new()
	var phase_configuration := {
		"schema_version": "catch_contact_phase_configuration_v1",
		"support_id": FLOOR_ID,
		"contact_confirm_ticks": int(contract["contact_confirm_ticks"]),
		"load_confirm_ticks": int(contract["load_confirm_ticks"]),
		"bearing_confirm_ticks": int(contract["bearing_confirm_ticks"]),
		"load_enter_n": float(contract["load_enter_n"]),
		"bearing_enter_n": float(contract["bearing_enter_n"]),
		"maximum_separating_speed_m_s": float(contract["maximum_separating_speed_m_s"]),
	}
	var configured := coordinator.configure(phase_configuration)
	if not bool(configured.get("ok", false)):
		viewport.queue_free()
		await tree.process_frame
		return {"ok": false, "failure_code": "BOUNDED_TOUCHDOWN_PHASE_CONFIGURATION_INVALID"}

	var bodies := {
		ROOT_ID: root,
		String(leg["link_1_id"]): link_1,
		String(leg["link_2_id"]): link_2,
	}
	var receipt_sink = ReceiptSinkScript.new("l4_6_bounded_touchdown")
	var fixture_complete := true
	var all_receipts_complete := true
	var contact_capacity_complete := true
	var executed_ticks := 0
	var first_touch_tick := -1
	var first_load_tick := -1
	var first_bearing_tick := -1
	var touchdown_approach_speed := 0.0
	var peak_predicted_load := 0.0
	var final_foot_speed := 0.0
	var maximum_penetration := 0.0
	var maximum_applied_torque := 0.0
	var maximum_pairing_residual := 0.0
	var actuator_saturation_count := 0
	var non_distal_contact_count := 0
	var target_arrival_used_for_transition := false
	var local_load_is_generalized_per_foot_allocation := false
	var phase_trace: Array[String] = []
	var prior_foot := _foot_position(leg, float(contract["link_length_m"]))
	var target_local: Array = contract["target_foot_local_m"]
	var target_world := root_position + Vector3(float(target_local[0]), float(target_local[1]), 0.0)
	var step_s := 1.0 / float(contract["physics_hz"])

	for tick in int(contract["trial_ticks"]):
		var ramp_fraction := clampf(
			float(tick + 1) / float(contract["target_ramp_ticks"]), 0.0, 1.0
		)
		var smooth_fraction := ramp_fraction * ramp_fraction * (3.0 - 2.0 * ramp_fraction)
		leg["target_q1_rad"] = lerpf(
			float(contract["initial_q1_rad"]), float(contract["target_q1_rad"]), smooth_fraction
		)
		leg["target_q2_rad"] = lerpf(
			float(contract["initial_q2_rad"]), float(contract["target_q2_rad"]), smooth_fraction
		)
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
					"run_id": "l4_6_bounded_touchdown",
					"command_id": tick,
					"source_frame_id": tick,
					"applied_transition": [tick, tick + 1],
					"mode": "L4_6_BOUNDED_TOUCHDOWN",
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

		var diagnostics: Dictionary = link_2.latest_contact_v2_diagnostics.get("observation", {})
		contact_capacity_complete = (
			contact_capacity_complete
			and bool(diagnostics.get("finite", false))
			and not bool(diagnostics.get("saturated_ever", true))
		)
		var distal_contacts: Array = []
		for raw_value in link_2.latest_contacts_v2:
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
					"target_arrived": tick + 1 >= int(contract["target_ramp_ticks"]),
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
		var foot := _foot_position(leg, float(contract["link_length_m"]))
		final_foot_speed = foot.distance_to(prior_foot) / step_s
		prior_foot = foot
		maximum_penetration = maxf(maximum_penetration, float(contract["foot_radius_m"]) - foot.y)

	var final_foot := _foot_position(leg, float(contract["link_length_m"]))
	var summary := {
		"schema_version": "bounded_touchdown_summary_v1",
		"configuration_sha256": contract["configuration_sha256"],
		"actuator_spec_sha256": actuator_spec["spec_sha256"],
		"fixture_complete": fixture_complete,
		"executed_ticks": executed_ticks,
		"first_touch_tick": first_touch_tick,
		"first_load_tick": first_load_tick,
		"first_bearing_tick": first_bearing_tick,
		"final_phase": coordinator.phase(),
		"phase_trace": phase_trace,
		"touchdown_approach_speed_m_s": touchdown_approach_speed,
		"peak_predicted_local_normal_load_n": peak_predicted_load,
		"final_foot_speed_m_s": final_foot_speed,
		"final_horizontal_error_m": absf(final_foot.x - target_world.x),
		"maximum_penetration_m": maximum_penetration,
		"maximum_applied_torque_nm": maximum_applied_torque,
		"maximum_pairing_residual_nm": maximum_pairing_residual,
		"actuator_saturation_count": actuator_saturation_count,
		"non_distal_contact_count": non_distal_contact_count,
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
		"contact_capacity_complete": contact_capacity_complete,
		"target_arrival_used_for_phase_transition": target_arrival_used_for_transition,
		"local_load_is_generalized_per_foot_allocation":
		local_load_is_generalized_per_foot_allocation,
		"root_assist_operation_count": 0,
		"foot_pin_operation_count": 0,
		"pose_teleport_operation_count": 0,
		"automatic_creature_guidance_operation_count": 0,
	}
	viewport.queue_free()
	await tree.process_frame
	await tree.physics_frame
	return {"ok": true, "summary": summary}


static func _build_touchdown_leg(hip: Vector3, contract: Dictionary, clock) -> Dictionary:
	var length := float(contract["link_length_m"])
	var mass := float(contract["link_mass_kg"])
	var radius := float(contract["foot_radius_m"])
	var q1 := float(contract["initial_q1_rad"])
	var q2 := float(contract["initial_q2_rad"])
	var absolute_2 := q1 + q2
	var direction_1 := Vector3(sin(q1), -cos(q1), 0.0)
	var direction_2 := Vector3(sin(absolute_2), -cos(absolute_2), 0.0)
	var knee := hip + length * direction_1
	var link_1_id := "br10_touchdown_link_1"
	var link_1 := _build_link(
		link_1_id, hip + 0.5 * length * direction_1, q1, mass, length, false, radius
	)
	var capacity_result := (
		CapacityScript
		. derive(
			{
				"body_id": DISTAL_BODY_ID,
				"expected_simultaneous_raw_points": 4,
				"safety_margin_raw_points": 4,
				"policy_max_cap_per_body": 16,
			}
		)
	)
	if not bool(capacity_result.get("ok", false)):
		return {"ok": false, "failure_code": "BOUNDED_TOUCHDOWN_CONTACT_CAPACITY_INVALID"}
	var link_2 := _build_observed_distal_link(
		knee + 0.5 * length * direction_2,
		absolute_2,
		mass,
		length,
		radius,
		clock,
		capacity_result["capacity"]
	)
	return {
		"ok": true,
		"leg":
		{
			"label": "touchdown",
			"hip_local_x_m": hip.x,
			"target_q1_rad": q1,
			"target_q2_rad": q2,
			"initial_hip": hip,
			"initial_knee": knee,
			"initial_link_1_position": link_1.position,
			"initial_link_2_position": link_2.position,
			"link_1_id": link_1_id,
			"link_2_id": DISTAL_BODY_ID,
			"link_1": link_1,
			"link_2": link_2,
			"hip_hinge": _build_hinge("br10_touchdown_hip", hip),
			"knee_hinge": _build_hinge("br10_touchdown_knee", knee),
			"previous_active_1": 0.0,
			"previous_active_2": 0.0,
			"previous_activation_1": 1.0,
			"previous_activation_2": 1.0,
		},
	}


static func _build_observed_distal_link(
	position: Vector3,
	absolute_angle: float,
	mass_kg: float,
	length_m: float,
	foot_radius_m: float,
	clock,
	contact_capacity: Dictionary
) -> RigidBody3D:
	var body = ObservedRigidBodyScript.new()
	body.name = DISTAL_BODY_ID
	body.body_id = StringName(DISTAL_BODY_ID)
	body.creature_id = &"br10_touchdown_fixture"
	body.support_role = &"unary_touchdown_distal"
	body.part_index = 1
	body.capture_clock = clock
	body.observer_profile = {
		"profile_id": "br10_touchdown_contacts_v2",
		"contacts_enabled": true,
		"contact_cap_per_body": 0,
		"contact_policy_max_cap_per_body": 16,
		"normal_epsilon_squared": 1.0e-12,
		"channels": ["raw_contacts_v2"],
	}
	body.run_id = "l4_6_bounded_touchdown"
	body.capture_stream_id = "l4_6_distal_contact_stream"
	body.contact_capacity = contact_capacity
	body.position = position
	body.rotation = Vector3(0.0, 0.0, absolute_angle - PI * 0.5)
	body.mass = mass_kg
	body.gravity_scale = 1.0
	body.can_sleep = false
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.freeze = true
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector3.ZERO
	body.inertia = Vector3(
		mass_kg * (LINK_WIDTH_M * LINK_WIDTH_M + LINK_DEPTH_M * LINK_DEPTH_M) / 12.0,
		mass_kg * (length_m * length_m + LINK_DEPTH_M * LINK_DEPTH_M) / 12.0,
		mass_kg * (length_m * length_m + LINK_WIDTH_M * LINK_WIDTH_M) / 12.0
	)
	body.collision_layer = LAB_COLLISION_LAYER
	body.collision_mask = LAB_COLLISION_LAYER
	var link_collision := CollisionShape3D.new()
	link_collision.name = LINK_SHAPE_ID
	link_collision.set_meta("lab_shape_id", LINK_SHAPE_ID)
	var link_shape := BoxShape3D.new()
	link_shape.size = Vector3(length_m - 2.0 * foot_radius_m, LINK_WIDTH_M, LINK_DEPTH_M)
	link_collision.shape = link_shape
	body.add_child(link_collision)
	var foot := CollisionShape3D.new()
	foot.name = DISTAL_SHAPE_ID
	foot.position = Vector3(length_m * 0.5, 0.0, 0.0)
	foot.set_meta("lab_shape_id", DISTAL_SHAPE_ID)
	var sphere := SphereShape3D.new()
	sphere.radius = foot_radius_m
	foot.shape = sphere
	body.add_child(foot)
	return body


static func _build_semantic_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = FLOOR_ID
	floor.position = Vector3(0.0, -0.5, 0.0)
	floor.collision_layer = LAB_COLLISION_LAYER
	floor.collision_mask = LAB_COLLISION_LAYER
	floor.set_meta("lab_surface_id", FLOOR_ID)
	floor.set_meta("lab_surface_tag", "lab_ground")
	floor.set_meta("lab_surface_layer", 1)
	var collision := CollisionShape3D.new()
	collision.name = FLOOR_SHAPE_ID
	collision.set_meta("lab_shape_id", FLOOR_SHAPE_ID)
	var shape := BoxShape3D.new()
	shape.size = Vector3(8.0, 1.0, 8.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor
