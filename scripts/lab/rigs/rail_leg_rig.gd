class_name LabRailLegRig
extends RefCounted
# gdlint: disable=max-file-lines

## BR6A/L4.3 two-link leg on an explicit vertical carriage rail.

const ActuationExecutorScript := preload("res://scripts/lab/actuation_executor.gd")
const BodyWrenchScript := preload("res://scripts/lab/mechanics/body_wrench.gd")
const CommandLedgerScript := preload("res://scripts/lab/command_ledger.gd")
const ForceMapScript := preload("res://scripts/lab/mechanics/force_to_joint_map.gd")
const JointActuatorScript := preload("res://scripts/lab/mechanics/joint_actuator.gd")
const ReconstructorScript := preload(
	"res://scripts/lab/mechanics/external_contact_impulse_reconstructor.gd"
)
const SupportAnalyzerScript := preload(
	"res://scripts/lab/mechanics/rail_leg_support_analyzer.gd"
)
const VerticalAllocatorScript := preload(
	"res://scripts/lab/mechanics/vertical_load_allocator.gd"
)
const ReceiptSinkScript := preload("res://scripts/lab/records/execution_receipt.gd")

const LAB_COLLISION_LAYER := 1 << 20
const CARRIAGE_ID := "l4_3_carriage"
const LINK_1_ID := "l4_3_link_1"
const LINK_2_ID := "l4_3_link_2"
const CARRIAGE_SIZE_M := Vector3(0.20, 0.16, 0.20)
const LINK_WIDTH_M := 0.05
const LINK_DEPTH_M := 0.08


func run(
	tree: SceneTree, contract: Dictionary, actuator_spec: Dictionary
) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "L4_3_RailLeg"
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var world := Node3D.new()
	world.name = "L4_3_RailLegWorld"
	var initial_ik := SupportAnalyzerScript.symmetric_ik(
		contract, float(contract["baseline_height_m"])
	)
	if not bool(initial_ik.get("ok", false)):
		viewport.queue_free()
		await tree.physics_frame
		return {"ok": false, "failure_code": "RAIL_LEG_INITIAL_IK_INVALID"}
	var pose := _pose_for_ik(contract, initial_ik)
	var anchor := _build_anchor(pose["hip_position"])
	var carriage := _build_carriage(
		pose["hip_position"], float(contract["carriage_mass_kg"])
	)
	var link_1 := _build_link(
		LINK_1_ID,
		pose["link_1_position"],
		float(initial_ik["joint_1_angle_rad"]),
		float(contract["link_1_mass_kg"]),
		float(contract["link_1_length_m"]),
		false,
		float(contract["foot_radius_m"])
	)
	var link_2 := _build_link(
		LINK_2_ID,
		pose["link_2_position"],
		float(initial_ik["absolute_link_2_angle_rad"]),
		float(contract["link_2_mass_kg"]),
		float(contract["link_2_length_m"]),
		true,
		float(contract["foot_radius_m"])
	)
	var rail := _build_rail(pose["hip_position"])
	var hip_hinge := _build_hinge("l4_3_hip", pose["hip_position"])
	var knee_hinge := _build_hinge("l4_3_knee", pose["knee_position"])
	var floor := _build_floor()
	for node in [anchor, carriage, link_1, link_2, rail, hip_hinge, knee_hinge, floor]:
		world.add_child(node)
	viewport.add_child(world)
	rail.node_a = rail.get_path_to(anchor)
	rail.node_b = rail.get_path_to(carriage)
	hip_hinge.node_a = hip_hinge.get_path_to(carriage)
	hip_hinge.node_b = hip_hinge.get_path_to(link_1)
	knee_hinge.node_a = knee_hinge.get_path_to(link_1)
	knee_hinge.node_b = knee_hinge.get_path_to(link_2)
	await tree.process_frame
	await tree.physics_frame
	carriage.freeze = false
	link_1.freeze = false
	link_2.freeze = false
	_reset_pose(carriage, link_1, link_2, pose, initial_ik)

	var gravity_vector := _gravity_acceleration_world()
	var gravity := gravity_vector.length()
	var total_mass := carriage.mass + link_1.mass + link_2.mass
	var step_s := 1.0 / float(contract["physics_hz"])
	var total_ticks := int(contract["total_ticks"])
	var settle_end := int(contract["settle_ticks"])
	var crouch_ramp_end := settle_end + int(contract["crouch_ramp_ticks"])
	var crouch_hold_end := crouch_ramp_end + int(contract["crouch_hold_ticks"])
	var rise_ramp_end := crouch_hold_end + int(contract["rise_ramp_ticks"])
	var recovery_start := rise_ramp_end + int(contract["rise_hold_ticks"])
	var receipt_sink = ReceiptSinkScript.new("l4_3_rail_leg")
	var bodies := {
		CARRIAGE_ID: carriage,
		LINK_1_ID: link_1,
		LINK_2_ID: link_2,
	}
	var previous_load := total_mass * gravity
	var previous_active_1 := 0.0
	var previous_active_2 := 0.0
	var previous_activation_1 := 1.0
	var previous_activation_2 := 1.0
	var fixture_complete := true
	var all_receipts_complete := true
	var maximum_pairing_residual := 0.0
	var maximum_requested_torque := 0.0
	var maximum_applied_torque := 0.0
	var actuator_saturation_count := 0
	var allocator_saturation_count := 0
	var allocator_anti_windup_count := 0
	var contact_samples := 0
	var measured_contact_samples := 0
	var static_maximum_height_error := 0.0
	var static_maximum_velocity := 0.0
	var static_maximum_support_error := 0.0
	var crouch_minimum_height := INF
	var rise_work := 0.0
	var crouch_potential := NAN
	var risen_potential := NAN
	var risen_height := NAN
	var impulse_minimum_height := INF
	var recovery_dwell := 0
	var recovery_tick := -1
	var maximum_rail_tangential_load := 0.0
	var disturbance_operation_count := 0
	var initial_baseline_height := float(contract["baseline_height_m"])
	for tick in total_ticks:
		var target_height := _target_height(
			contract,
			tick,
			settle_end,
			crouch_ramp_end,
			crouch_hold_end,
			rise_ramp_end,
			recovery_start
		)
		var target_ik := SupportAnalyzerScript.symmetric_ik(contract, target_height)
		if not bool(target_ik.get("ok", false)):
			fixture_complete = false
			break
		if tick == recovery_start:
			carriage.apply_central_impulse(
				Vector3.DOWN * float(contract["downward_impulse_ns"])
			)
			disturbance_operation_count += 1
		var q1 := _absolute_angle(link_1)
		var absolute_q2 := _absolute_angle(link_2)
		var q2 := wrapf(absolute_q2 - q1, -PI, PI)
		var q1_rate := (
			(link_1.angular_velocity - carriage.angular_velocity).dot(Vector3.BACK)
		)
		var q2_rate := (
			(link_2.angular_velocity - link_1.angular_velocity).dot(Vector3.BACK)
		)
		var allocator := VerticalAllocatorScript.allocate(
			{
				"schema_version": "vertical_load_allocation_request_v1",
				"tick": tick,
				"mass_kg": total_mass,
				"gravity_m_s2": gravity,
				"height_error_m": target_height - carriage.global_position.y,
				"vertical_velocity_m_s": carriage.linear_velocity.y,
				"position_gain_n_m": float(contract["height_position_gain_n_m"]),
				"velocity_gain_n_s_m": float(contract["height_velocity_gain_n_s_m"]),
				"minimum_load_n": float(contract["minimum_load_n"]),
				"maximum_load_n": float(contract["maximum_load_n"]),
				"previous_load_n": previous_load,
				"maximum_load_rate_n_s": float(contract["maximum_load_rate_n_s"]),
				"step_s": step_s,
			}
		)
		if not bool(allocator.get("ok", false)):
			fixture_complete = false
			break
		var allocation: Dictionary = allocator["allocation"]
		var desired_load := float(allocation["applied_load_n"])
		var foot_position := (
			link_2.global_position
			+ 0.5 * float(contract["link_2_length_m"]) * link_2.global_basis.x.normalized()
		)
		var wrench_build := BodyWrenchScript.compile(
			{
				"schema_version": "body_wrench_v1",
				"wrench_id": "l4_3.tick_%06d" % tick,
				"source_id": "l4_3.vertical_allocator",
				"frame_id": "world",
				"application_point_world_m":
				[foot_position.x, foot_position.y, foot_position.z],
				"force_world_n": [0.0, desired_load, 0.0],
				"moment_world_nm": [0.0, 0.0, 0.0],
			}
		)
		if not bool(wrench_build.get("ok", false)):
			fixture_complete = false
			break
		var force_map := ForceMapScript.map(
			SupportAnalyzerScript.force_map_request(
				contract, q1, q2, wrench_build["wrench"]
			)
		)
		if not bool(force_map.get("ok", false)):
			fixture_complete = false
			break
		var mapping: Dictionary = force_map["mapping"]
		var request_1 := (
			float(mapping["joint_1_feedforward_nm"])
			- float(contract["joint_position_gain_nm_rad"])
			* (q1 - float(target_ik["joint_1_angle_rad"]))
			- float(contract["joint_velocity_gain_nm_s_rad"]) * q1_rate
		)
		var request_2 := (
			float(mapping["joint_2_feedforward_nm"])
			- float(contract["joint_position_gain_nm_rad"])
			* (q2 - float(target_ik["joint_2_angle_rad"]))
			- float(contract["joint_velocity_gain_nm_s_rad"]) * q2_rate
		)
		var plan_1 := _plan(
			tick,
			"l4_3_hip",
			CARRIAGE_ID,
			LINK_1_ID,
			carriage.global_position,
			q1_rate,
			request_1,
			float(mapping["joint_1_feedforward_nm"]),
			previous_active_1,
			previous_activation_1,
			step_s,
			actuator_spec
		)
		var knee_position := (
			link_1.global_position
			+ 0.5 * float(contract["link_1_length_m"]) * link_1.global_basis.x.normalized()
		)
		var plan_2 := _plan(
			tick,
			"l4_3_knee",
			LINK_1_ID,
			LINK_2_ID,
			knee_position,
			q2_rate,
			request_2,
			float(mapping["joint_2_feedforward_nm"]),
			previous_active_2,
			previous_activation_2,
			step_s,
			actuator_spec
		)
		if not bool(plan_1.get("ok", false)) or not bool(plan_2.get("ok", false)):
			fixture_complete = false
			break
		var resolution_1: Dictionary = plan_1["resolution"]
		var resolution_2: Dictionary = plan_2["resolution"]
		var command_1: Dictionary = plan_1["command"]
		var command_2: Dictionary = plan_2["command"]
		var ledger = CommandLedgerScript.new()
		fixture_complete = ledger.begin_tick(tick) and fixture_complete
		fixture_complete = ledger.queue_joint(command_1) and fixture_complete
		fixture_complete = ledger.queue_joint(command_2) and fixture_complete
		var envelope := ledger.seal(
			{
				"run_id": "l4_3_rail_leg",
				"command_id": tick,
				"source_frame_id": tick,
				"applied_transition": [tick, tick + 1],
				"mode": "L4_3_VERTICAL_RAIL_SUPPORT",
			}
		)
		var before := [
			_momentum_sample(carriage, CARRIAGE_ID),
			_momentum_sample(link_1, LINK_1_ID),
			_momentum_sample(link_2, LINK_2_ID),
		]
		var before_receipts := receipt_sink.values().size()
		var execution := ActuationExecutorScript.apply_command_envelope(
			envelope, bodies, receipt_sink
		)
		await tree.physics_frame
		for body in [carriage, link_1, link_2]:
			body.sleeping = false
		var receipts: Array = receipt_sink.values().slice(before_receipts)
		var operations: Array = []
		operations.append_array(command_1["planned_application_operations"])
		operations.append_array(command_2["planned_application_operations"])
		var receipts_match := _receipts_match(
			receipts, String(envelope["command_payload_sha256"]), operations
		)
		all_receipts_complete = all_receipts_complete and receipts_match
		fixture_complete = (
			fixture_complete
			and bool(execution.get("ok", false))
			and int(execution.get("applied_count", -1)) == 4
			and receipts_match
		)
		var after := [
			_momentum_sample(carriage, CARRIAGE_ID),
			_momentum_sample(link_1, LINK_1_ID),
			_momentum_sample(link_2, LINK_2_ID),
		]
		var reconstruction := ReconstructorScript.reconstruct(
			before,
			after,
			step_s,
			total_mass * gravity_vector * step_s,
			Vector3.UP
		)
		if not bool(reconstruction.get("reconstruction_valid", false)):
			fixture_complete = false
			break
		var support := float(
			reconstruction["reconstructed_step_average_normal_load_n"]
		)
		var tangential_impulse: Vector3 = (
			reconstruction["reconstructed_tangential_impulse_world_ns"]
		)
		maximum_rail_tangential_load = maxf(
			maximum_rail_tangential_load, tangential_impulse.length() / step_s
		)
		var applied_1 := float(resolution_1["applied_total_nm"])
		var applied_2 := float(resolution_2["applied_total_nm"])
		maximum_requested_torque = maxf(
			maximum_requested_torque,
			maxf(
				absf(float(resolution_1["requested_active_nm"])),
				absf(float(resolution_2["requested_active_nm"]))
			)
		)
		maximum_applied_torque = maxf(
			maximum_applied_torque, maxf(absf(applied_1), absf(applied_2))
		)
		maximum_pairing_residual = maxf(
			maximum_pairing_residual,
			maxf(
				float((command_1["diagnostics"] as Dictionary)["pairing_residual_nm"]),
				float((command_2["diagnostics"] as Dictionary)["pairing_residual_nm"])
			)
		)
		if _resolution_saturated(resolution_1) or _resolution_saturated(resolution_2):
			actuator_saturation_count += 1
		if bool(allocation["saturated"]):
			allocator_saturation_count += 1
		if bool(allocation["anti_windup_active"]):
			allocator_anti_windup_count += 1
		if tick >= settle_end / 2:
			measured_contact_samples += 1
			if floor in link_2.get_colliding_bodies():
				contact_samples += 1
		if tick >= settle_end / 2 and tick < settle_end:
			static_maximum_height_error = maxf(
				static_maximum_height_error,
				absf(carriage.global_position.y - float(contract["baseline_height_m"]))
			)
			static_maximum_velocity = maxf(
				static_maximum_velocity, absf(carriage.linear_velocity.y)
			)
			static_maximum_support_error = maxf(
				static_maximum_support_error, absf(support - total_mass * gravity)
			)
		if tick >= crouch_ramp_end and tick < crouch_hold_end:
			crouch_minimum_height = minf(crouch_minimum_height, carriage.global_position.y)
		if tick == crouch_hold_end - 1:
			crouch_potential = _potential_energy(carriage, link_1, link_2, gravity)
		if tick >= crouch_hold_end and tick < recovery_start:
			rise_work += (applied_1 * q1_rate + applied_2 * q2_rate) * step_s
		if tick == recovery_start - 1:
			risen_potential = _potential_energy(carriage, link_1, link_2, gravity)
			risen_height = carriage.global_position.y
		if tick >= recovery_start:
			impulse_minimum_height = minf(impulse_minimum_height, carriage.global_position.y)
			var recovered_now := (
				absf(carriage.global_position.y - initial_baseline_height)
					<= float(contract["maximum_recovery_height_error_m"])
				and absf(carriage.linear_velocity.y)
					<= float(contract["maximum_recovery_velocity_m_s"])
			)
			recovery_dwell = recovery_dwell + 1 if recovered_now else 0
			if (
				recovery_tick < 0
				and recovery_dwell >= int(contract["recovery_dwell_ticks"])
			):
				recovery_tick = tick - recovery_start + 1
		previous_load = desired_load
		previous_active_1 = float(resolution_1["applied_active_nm"])
		previous_active_2 = float(resolution_2["applied_active_nm"])
		previous_activation_1 = float(resolution_1["activation_next"])
		previous_activation_2 = float(resolution_2["activation_next"])
	var final_height_error := absf(
		carriage.global_position.y - float(contract["baseline_height_m"])
	)
	var final_velocity := absf(carriage.linear_velocity.y)
	var summary := {
		"fixture_complete": fixture_complete,
		"sample_count": total_ticks if fixture_complete else 0,
		"static_maximum_height_error_m": static_maximum_height_error,
		"static_maximum_velocity_m_s": static_maximum_velocity,
		"static_maximum_support_error_n": static_maximum_support_error,
		"contact_fraction":
		float(contact_samples) / float(maxi(measured_contact_samples, 1)),
		"crouch_depth_m": initial_baseline_height - crouch_minimum_height,
		"final_rise_height_error_m":
		absf(risen_height - float(contract["baseline_height_m"])),
		"rise_potential_energy_gain_j": risen_potential - crouch_potential,
		"rise_active_work_j": rise_work,
		"impulse_maximum_drop_m": initial_baseline_height - impulse_minimum_height,
		"impulse_recovered": recovery_tick >= 0,
		"impulse_recovery_ticks": maxi(recovery_tick, 0),
		"recovery_final_height_error_m": final_height_error,
		"recovery_final_velocity_m_s": final_velocity,
		"rail_contract_exact": _rail_contract_exact(rail),
		"hinges_exact": _hinge_exact(hip_hinge) and _hinge_exact(knee_hinge),
		"all_receipts_complete": all_receipts_complete,
		"maximum_pairing_residual_nm": maximum_pairing_residual,
		"maximum_requested_torque_nm": maximum_requested_torque,
		"maximum_applied_torque_nm": maximum_applied_torque,
		"actuator_saturation_count": actuator_saturation_count,
		"allocator_saturation_count": allocator_saturation_count,
		"allocator_anti_windup_count": allocator_anti_windup_count,
		"disturbance_operation_count": disturbance_operation_count,
		"root_rescue_operation_count": 0,
		"passive_operation_count": 0,
		"foot_pin_operation_count": 0,
		"maximum_rail_tangential_load_n": maximum_rail_tangential_load,
		"per_foot_allocation_available": false,
	}
	var result := {"ok": fixture_complete, "summary": summary}
	viewport.queue_free()
	await tree.physics_frame
	return result


static func _target_height(
	contract: Dictionary,
	tick: int,
	settle_end: int,
	crouch_ramp_end: int,
	crouch_hold_end: int,
	rise_ramp_end: int,
	recovery_start: int
) -> float:
	var baseline := float(contract["baseline_height_m"])
	var crouch := float(contract["crouch_height_m"])
	if tick < settle_end:
		return baseline
	if tick < crouch_ramp_end:
		var crouch_phase := float(tick - settle_end + 1) / float(
			int(contract["crouch_ramp_ticks"])
		)
		return lerpf(baseline, crouch, _smoothstep(crouch_phase))
	if tick < crouch_hold_end:
		return crouch
	if tick < rise_ramp_end:
		var rise_phase := float(tick - crouch_hold_end + 1) / float(
			int(contract["rise_ramp_ticks"])
		)
		return lerpf(crouch, baseline, _smoothstep(rise_phase))
	if tick < recovery_start:
		return baseline
	return baseline


static func _smoothstep(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


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
	step_s: float,
	actuator_spec: Dictionary
) -> Dictionary:
	return JointActuatorScript.resolve_and_plan(
		{
			"schema_version": "joint_actuator_input_v1",
			"tick": tick,
			"joint_id": joint_id,
			"parent_body_id": parent_id,
			"child_body_id": child_id,
			"source_id": "l4_3_height_support",
			"behavior_state": "RAIL_SUPPORT",
			"axis_world": Vector3.BACK,
			"pivot_world": pivot,
			"angular_velocity_rad_s": rate,
			"active_components":
			{
				"l4_3.force_map_feedforward": feedforward,
				"l4_3.joint_tracking": requested - feedforward,
			},
			"passive_components": {},
			"previous_active_nm": previous_active,
			"previous_activation": previous_activation,
			"step_s": step_s,
		},
		actuator_spec
	)


static func _pose_for_ik(contract: Dictionary, ik: Dictionary) -> Dictionary:
	var q1 := float(ik["joint_1_angle_rad"])
	var absolute_2 := float(ik["absolute_link_2_angle_rad"])
	var l1 := float(contract["link_1_length_m"])
	var l2 := float(contract["link_2_length_m"])
	var hip := Vector3(0.0, float(contract["baseline_height_m"]), 0.0)
	var direction_1 := Vector3(sin(q1), -cos(q1), 0.0)
	var direction_2 := Vector3(sin(absolute_2), -cos(absolute_2), 0.0)
	var knee := hip + l1 * direction_1
	return {
		"hip_position": hip,
		"knee_position": knee,
		"link_1_position": hip + 0.5 * l1 * direction_1,
		"link_2_position": knee + 0.5 * l2 * direction_2,
	}


static func _reset_pose(
	carriage: RigidBody3D,
	link_1: RigidBody3D,
	link_2: RigidBody3D,
	pose: Dictionary,
	ik: Dictionary
) -> void:
	carriage.global_position = pose["hip_position"]
	carriage.quaternion = Quaternion.IDENTITY
	link_1.global_position = pose["link_1_position"]
	link_1.rotation = Vector3(
		0.0, 0.0, float(ik["joint_1_angle_rad"]) - PI * 0.5
	)
	link_2.global_position = pose["link_2_position"]
	link_2.rotation = Vector3(
		0.0, 0.0, float(ik["absolute_link_2_angle_rad"]) - PI * 0.5
	)
	for body in [carriage, link_1, link_2]:
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = false


static func _build_carriage(position: Vector3, mass_kg: float) -> RigidBody3D:
	var body := _body(CARRIAGE_ID, position, mass_kg)
	body.collision_layer = 0
	body.collision_mask = 0
	_add_box(body, CARRIAGE_SIZE_M, Vector3.ZERO)
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
	body.collision_layer = LAB_COLLISION_LAYER if has_foot else 0
	body.collision_mask = LAB_COLLISION_LAYER if has_foot else 0
	body.contact_monitor = has_foot
	body.max_contacts_reported = 16 if has_foot else 0
	var collision_length := (
		length_m - 2.0 * foot_radius_m if has_foot else length_m
	)
	_add_box(
		body,
		Vector3(collision_length, LINK_WIDTH_M, LINK_DEPTH_M),
		Vector3.ZERO
	)
	if has_foot:
		var foot := CollisionShape3D.new()
		foot.name = "ordinary_distal_sphere"
		foot.position = Vector3(length_m * 0.5, 0.0, 0.0)
		var sphere := SphereShape3D.new()
		sphere.radius = foot_radius_m
		foot.shape = sphere
		body.add_child(foot)
		var material := PhysicsMaterial.new()
		material.friction = 0.0
		material.bounce = 0.0
		body.physics_material_override = material
	return body


static func _body(
	body_id: String, position: Vector3, mass_kg: float
) -> RigidBody3D:
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
	anchor.name = "l4_3_rail_anchor"
	anchor.position = position
	anchor.collision_layer = 0
	anchor.collision_mask = 0
	return anchor


static func _build_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "l4_3_floor"
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
	rail.name = "l4_3_vertical_rail"
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


static func _build_hinge(name_value: String, position: Vector3) -> HingeJoint3D:
	var hinge := HingeJoint3D.new()
	hinge.name = name_value
	hinge.position = position
	hinge.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
	hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, false)
	return hinge


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


static func _hinge_exact(hinge: HingeJoint3D) -> bool:
	return (
		not hinge.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR)
		and not hinge.get_flag(HingeJoint3D.FLAG_USE_LIMIT)
	)


static func _absolute_angle(body: RigidBody3D) -> float:
	var direction := body.global_basis.x.normalized()
	return atan2(direction.x, -direction.y)


static func _potential_energy(
	carriage: RigidBody3D, link_1: RigidBody3D, link_2: RigidBody3D, gravity: float
) -> float:
	return gravity * (
		carriage.mass * carriage.global_position.y
		+ link_1.mass * link_1.global_position.y
		+ link_2.mass * link_2.global_position.y
	)


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


static func _resolution_saturated(resolution: Dictionary) -> bool:
	return (
		bool(resolution["active_saturated"])
		or bool(resolution["torque_rate_limited"])
		or bool(resolution["structural_saturated"])
	)


static func _add_box(
	parent: CollisionObject3D, size: Vector3, local_position: Vector3
) -> void:
	var collision := CollisionShape3D.new()
	collision.position = local_position
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	parent.add_child(collision)


static func _receipts_match(
	receipts: Array, payload_hash: String, operations: Array
) -> bool:
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
			or expected[String(receipt["operation_id"])]
				!= String(receipt.get("target_body_id", ""))
		):
			return false
	return true
