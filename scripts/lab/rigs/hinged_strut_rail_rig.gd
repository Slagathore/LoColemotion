class_name LabHingedStrutRailRig
extends RefCounted
# gdlint: disable=max-file-lines

## L4.1 one-hinge loaded strut on the explicit vertical rail.

const ActuationExecutorScript := preload("res://scripts/lab/actuation_executor.gd")
const CommandLedgerScript := preload("res://scripts/lab/command_ledger.gd")
const JointActuatorScript := preload("res://scripts/lab/mechanics/joint_actuator.gd")
const ReconstructorScript := preload(
	"res://scripts/lab/mechanics/external_contact_impulse_reconstructor.gd"
)
const ReceiptSinkScript := preload("res://scripts/lab/records/execution_receipt.gd")

const LAB_COLLISION_LAYER := 1 << 20
const CARRIAGE_ID := "l4_1_carriage"
const LINK_ID := "l4_1_strut"
const CARRIAGE_SIZE_M := Vector3(0.20, 0.16, 0.20)
const LINK_SIZE_M := Vector3(0.60, 0.06, 0.08)
const FOOT_RADIUS_M := 0.06


func run(
	tree: SceneTree,
	configuration: Dictionary,
	actuator_spec: Dictionary,
	target_angle_deg: float,
	active_hold: bool
) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "HingedStrut_%03d_%s" % [
		int(target_angle_deg),
		"hold" if active_hold else "control",
	]
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var world := Node3D.new()
	var theta := deg_to_rad(target_angle_deg)
	var direction := Vector3(sin(theta), -cos(theta), 0.0)
	var hip_position := Vector3(
		0.0,
		FOOT_RADIUS_M + float(configuration["link_length_m"]) * cos(theta),
		0.0
	)
	var carriage := _build_carriage(
		hip_position, float(configuration["carriage_mass_kg"])
	)
	var link := _build_link(
		hip_position,
		direction,
		theta,
		float(configuration["link_mass_kg"]),
		float(configuration["link_length_m"])
	)
	var anchor := _build_anchor(hip_position)
	var rail := _build_rail(hip_position)
	var hinge := _build_hinge(hip_position)
	var floor := _build_floor()
	world.add_child(anchor)
	world.add_child(carriage)
	world.add_child(link)
	world.add_child(rail)
	world.add_child(hinge)
	world.add_child(floor)
	viewport.add_child(world)
	rail.node_a = rail.get_path_to(anchor)
	rail.node_b = rail.get_path_to(carriage)
	hinge.node_a = hinge.get_path_to(carriage)
	hinge.node_b = hinge.get_path_to(link)
	await tree.process_frame
	await tree.physics_frame
	carriage.freeze = false
	link.freeze = false
	_reset_pose(carriage, link, hip_position, direction, theta, float(configuration["link_length_m"]))

	var step_s := 1.0 / float(configuration["physics_hz"])
	var total_ticks := int(configuration["settle_ticks"]) + int(configuration["analysis_ticks"])
	var gravity_magnitude := _gravity_acceleration_world().length()
	var horizontal_reach := float(configuration["link_length_m"]) * sin(theta)
	var expected_torque := (
		-horizontal_reach
		* (
			float(configuration["carriage_mass_kg"])
			+ 0.5 * float(configuration["link_mass_kg"])
		)
		* gravity_magnitude
	)
	var receipt_sink = ReceiptSinkScript.new(
		"l4_1_%03d_%s" % [int(target_angle_deg), "hold" if active_hold else "control"]
	)
	var previous_active := expected_torque if active_hold else 0.0
	var previous_activation := 1.0
	var initial_hip_height := carriage.global_position.y
	var valid_sample_count := 0
	var contact_samples := 0
	var expected_sum := 0.0
	var applied_sum := 0.0
	var support_sum := 0.0
	var maximum_torque_error := 0.0
	var maximum_support_error := 0.0
	var maximum_angle_error := 0.0
	var maximum_height_drift := 0.0
	var maximum_rate := 0.0
	var active_work := 0.0
	var all_receipts_complete := true
	var actuator_saturated := false
	var fixture_complete := true
	var bodies := {CARRIAGE_ID: carriage, LINK_ID: link}
	for tick in total_ticks:
		var current_angle := _signed_angle_from_vertical(link)
		var current_rate := (
			(link.angular_velocity - carriage.angular_velocity).dot(Vector3.BACK)
		)
		var stabilization_torque := 0.0
		if active_hold:
			stabilization_torque = (
				-float(configuration["hold_position_gain_nm_rad"])
				* (current_angle - theta)
				- float(configuration["hold_velocity_gain_nm_s_rad"]) * current_rate
			)
		var requested_torque := (
			expected_torque + stabilization_torque if active_hold else 0.0
		)
		var plan := JointActuatorScript.resolve_and_plan(
			{
				"schema_version": "joint_actuator_input_v1",
				"tick": tick,
				"joint_id": "l4_1_loaded_hinge",
				"parent_body_id": CARRIAGE_ID,
				"child_body_id": LINK_ID,
				"source_id": "l4_1_static_moment_balance",
				"behavior_state": "STATIC_HOLD" if active_hold else "ZERO_TORQUE_CONTROL",
				"axis_world": Vector3.BACK,
				"pivot_world": carriage.global_position,
				"angular_velocity_rad_s": current_rate,
				"active_components":
				{
					"l4_1.static_feedforward": expected_torque if active_hold else 0.0,
					"l4_1.joint_space_stabilization": stabilization_torque,
				},
				"passive_components": {},
				"previous_active_nm": previous_active,
				"previous_activation": previous_activation,
				"step_s": step_s,
			},
			actuator_spec
		)
		if not bool(plan.get("ok", false)):
			fixture_complete = false
			break
		var resolution: Dictionary = plan["resolution"]
		var command: Dictionary = plan["command"]
		var ledger = CommandLedgerScript.new()
		fixture_complete = ledger.begin_tick(tick) and fixture_complete
		fixture_complete = ledger.queue_joint(command) and fixture_complete
		var envelope := ledger.seal(
			{
				"run_id": "l4_1_hinged_strut",
				"command_id": tick,
				"source_frame_id": tick,
				"applied_transition": [tick, tick + 1],
				"mode": "L4_1_HINGED_STRUT_STATIC_LOAD",
			}
		)
		var before := [
			_momentum_sample(carriage, CARRIAGE_ID),
			_momentum_sample(link, LINK_ID),
		]
		var before_receipts := receipt_sink.values().size()
		var execution := ActuationExecutorScript.apply_command_envelope(
			envelope, bodies, receipt_sink
		)
		await tree.physics_frame
		carriage.sleeping = false
		link.sleeping = false
		var receipts: Array = receipt_sink.values().slice(before_receipts)
		var receipt_ok := _receipts_match(
			receipts,
			String(envelope["command_payload_sha256"]),
			command["planned_application_operations"]
		)
		all_receipts_complete = all_receipts_complete and receipt_ok
		fixture_complete = (
			fixture_complete
			and bool(execution.get("ok", false))
			and int(execution.get("applied_count", -1)) == 2
			and receipt_ok
		)
		var after := [
			_momentum_sample(carriage, CARRIAGE_ID),
			_momentum_sample(link, LINK_ID),
		]
		var total_mass := (
			float(configuration["carriage_mass_kg"]) + float(configuration["link_mass_kg"])
		)
		var reconstruction := ReconstructorScript.reconstruct(
			before,
			after,
			step_s,
			total_mass * _gravity_acceleration_world() * step_s,
			Vector3.UP
		)
		var applied := float(resolution["applied_total_nm"])
		actuator_saturated = (
			actuator_saturated
			or bool(resolution["active_saturated"])
			or bool(resolution["torque_rate_limited"])
			or bool(resolution["structural_saturated"])
		)
		var measured_angle := _signed_angle_from_vertical(link)
		var measured_rate := (
			(link.angular_velocity - carriage.angular_velocity).dot(Vector3.BACK)
		)
		if tick >= int(configuration["settle_ticks"]):
			if bool(reconstruction.get("reconstruction_valid", false)):
				valid_sample_count += 1
				var support := float(
					reconstruction["reconstructed_step_average_normal_load_n"]
				)
				support_sum += support
				maximum_support_error = maxf(
					maximum_support_error, absf(support - total_mass * gravity_magnitude)
				)
			if floor in link.get_colliding_bodies():
				contact_samples += 1
			expected_sum += expected_torque
			applied_sum += applied
			maximum_torque_error = maxf(maximum_torque_error, absf(applied - expected_torque))
			maximum_angle_error = maxf(maximum_angle_error, absf(measured_angle - theta))
			maximum_height_drift = maxf(
				maximum_height_drift, absf(carriage.global_position.y - initial_hip_height)
			)
			maximum_rate = maxf(maximum_rate, absf(measured_rate))
			active_work += applied * measured_rate * step_s
		previous_active = float(resolution["applied_active_nm"])
		previous_activation = float(resolution["activation_next"])
	var denominator := float(maxi(int(configuration["analysis_ticks"]), 1))
	var summary := {
		"mode": "analytic_hold" if active_hold else "zero_torque_control",
		"target_angle_deg": target_angle_deg,
		"valid_sample_count": valid_sample_count,
		"mean_expected_torque_nm": expected_sum / denominator,
		"mean_applied_torque_nm": applied_sum / denominator,
		"maximum_torque_error_nm": maximum_torque_error,
		"mean_reconstructed_support_n": support_sum / float(maxi(valid_sample_count, 1)),
		"maximum_support_load_error_n": maximum_support_error,
		"maximum_angle_error_rad": maximum_angle_error,
		"maximum_height_drift_m": maximum_height_drift,
		"maximum_joint_rate_rad_s": maximum_rate,
		"floor_contact_fraction":
		float(contact_samples) / float(maxi(int(configuration["analysis_ticks"]), 1)),
		"active_work_j": active_work,
		"rail_contract_exact": _rail_contract_exact(rail),
		"hinge_contract_exact":
		not hinge.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR)
			and not hinge.get_flag(HingeJoint3D.FLAG_USE_LIMIT),
		"all_receipts_complete": all_receipts_complete,
		"root_assistance_operation_count": 0,
		"passive_operation_count": 0,
		"actuator_saturated": actuator_saturated,
		"held_within_gate":
		maximum_angle_error <= float(configuration["maximum_angle_error_rad"])
			and maximum_height_drift <= float(configuration["maximum_height_drift_m"])
			and maximum_rate <= float(configuration["maximum_joint_rate_rad_s"]),
		"analytic_model": "frictionless_foot_static_moment_balance_v1",
		"rail_scaffold_explicit": true,
		"per_foot_load_allocation": false,
	}
	var result := {"ok": fixture_complete, "summary": summary}
	viewport.queue_free()
	await tree.physics_frame
	return result


static func _build_carriage(position: Vector3, mass_kg: float) -> RigidBody3D:
	var body := _body(CARRIAGE_ID, mass_kg, position)
	body.collision_layer = LAB_COLLISION_LAYER
	body.collision_mask = 0
	_add_box(body, CARRIAGE_SIZE_M, Vector3.ZERO)
	return body


static func _build_link(
	hip_position: Vector3,
	direction: Vector3,
	theta: float,
	mass_kg: float,
	length_m: float
) -> RigidBody3D:
	var body := _body(LINK_ID, mass_kg, hip_position + 0.5 * length_m * direction)
	body.rotation = Vector3(0.0, 0.0, theta - PI * 0.5)
	body.collision_layer = LAB_COLLISION_LAYER
	body.collision_mask = LAB_COLLISION_LAYER
	body.contact_monitor = true
	body.max_contacts_reported = 16
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector3.ZERO
	_add_box(
		body,
		Vector3(length_m - 2.0 * FOOT_RADIUS_M, LINK_SIZE_M.y, LINK_SIZE_M.z),
		Vector3.ZERO
	)
	var foot := CollisionShape3D.new()
	foot.name = "distal_sphere"
	foot.position = Vector3(length_m * 0.5, 0.0, 0.0)
	var sphere := SphereShape3D.new()
	sphere.radius = FOOT_RADIUS_M
	foot.shape = sphere
	body.add_child(foot)
	var material := PhysicsMaterial.new()
	material.friction = 0.0
	material.bounce = 0.0
	body.physics_material_override = material
	return body


static func _body(
	body_id: String,
	mass_kg: float,
	position: Vector3
) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = body_id
	body.mass = mass_kg
	body.gravity_scale = 1.0
	body.can_sleep = false
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.freeze = true
	body.position = position
	return body


static func _build_anchor(position: Vector3) -> StaticBody3D:
	var anchor := StaticBody3D.new()
	anchor.name = "l4_1_rail_anchor"
	anchor.position = position
	anchor.collision_layer = 0
	anchor.collision_mask = 0
	return anchor


static func _build_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "l4_1_floor"
	floor.position = Vector3(0.0, -0.5, 0.0)
	floor.collision_layer = LAB_COLLISION_LAYER
	floor.collision_mask = LAB_COLLISION_LAYER
	_add_box(floor, Vector3(8.0, 1.0, 8.0), Vector3.ZERO)
	var material := PhysicsMaterial.new()
	material.friction = 0.0
	material.bounce = 0.0
	floor.physics_material_override = material
	return floor


static func _build_rail(position: Vector3) -> Generic6DOFJoint3D:
	var rail := Generic6DOFJoint3D.new()
	rail.name = "l4_1_vertical_rail"
	rail.position = position
	for axis in ["x", "y", "z"]:
		rail.set("linear_limit_%s/enabled" % axis, axis != "y")
		rail.set("linear_limit_%s/lower_distance" % axis, 0.0)
		rail.set("linear_limit_%s/upper_distance" % axis, 0.0)
		rail.set("linear_motor_%s/enabled" % axis, false)
		rail.set("linear_spring_%s/enabled" % axis, false)
		rail.set("angular_limit_%s/enabled" % axis, true)
		rail.set("angular_limit_%s/lower_angle" % axis, 0.0)
		rail.set("angular_limit_%s/upper_angle" % axis, 0.0)
		rail.set("angular_motor_%s/enabled" % axis, false)
		rail.set("angular_spring_%s/enabled" % axis, false)
	return rail


static func _build_hinge(position: Vector3) -> HingeJoint3D:
	var hinge := HingeJoint3D.new()
	hinge.name = "l4_1_loaded_hinge"
	hinge.position = position
	hinge.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
	hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, false)
	return hinge


static func _reset_pose(
	carriage: RigidBody3D,
	link: RigidBody3D,
	hip_position: Vector3,
	direction: Vector3,
	theta: float,
	length_m: float
) -> void:
	carriage.global_position = hip_position
	carriage.quaternion = Quaternion.IDENTITY
	link.global_position = hip_position + 0.5 * length_m * direction
	link.rotation = Vector3(0.0, 0.0, theta - PI * 0.5)
	for body in [carriage, link]:
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = false


static func _rail_contract_exact(rail: Generic6DOFJoint3D) -> bool:
	if (
		not bool(rail.get("linear_limit_x/enabled"))
		or bool(rail.get("linear_limit_y/enabled"))
		or not bool(rail.get("linear_limit_z/enabled"))
	):
		return false
	for axis in ["x", "y", "z"]:
		if (
			bool(rail.get("linear_motor_%s/enabled" % axis))
			or bool(rail.get("linear_spring_%s/enabled" % axis))
			or bool(rail.get("angular_motor_%s/enabled" % axis))
			or bool(rail.get("angular_spring_%s/enabled" % axis))
			or not bool(rail.get("angular_limit_%s/enabled" % axis))
		):
			return false
	return true


static func _signed_angle_from_vertical(link: RigidBody3D) -> float:
	var direction := link.global_basis.x.normalized()
	return atan2(direction.x, -direction.y)


static func _momentum_sample(body: RigidBody3D, body_id: String) -> Dictionary:
	return {
		"body_id": body_id,
		"mass_kg": body.mass,
		"linear_velocity_world_mps": body.linear_velocity,
	}


static func _gravity_acceleration_world() -> Vector3:
	var magnitude := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var direction_value: Variant = ProjectSettings.get_setting(
		"physics/3d/default_gravity_vector", Vector3.DOWN
	)
	var direction := direction_value as Vector3 if direction_value is Vector3 else Vector3.DOWN
	return magnitude * direction.normalized()


static func _add_box(
	parent: CollisionObject3D,
	size: Vector3,
	local_position: Vector3
) -> void:
	var collision := CollisionShape3D.new()
	collision.position = local_position
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	parent.add_child(collision)


static func _receipts_match(receipts: Array, payload_hash: String, operations: Array) -> bool:
	if receipts.size() != 2 or operations.size() != 2:
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
			or expected[String(receipt["operation_id"])]
				!= String(receipt.get("target_body_id", ""))
		):
			return false
	return true
