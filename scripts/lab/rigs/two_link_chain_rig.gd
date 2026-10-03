class_name LabTwoLinkChainRig
extends RefCounted

## Live planar two-joint chain for L2.6 fixed/free root comparison.

const JointBindingScript := preload("res://scripts/lab/mechanics/joint_binding.gd")
const JointStateScript := preload("res://scripts/lab/mechanics/joint_state.gd")
const JointActuatorScript := preload("res://scripts/lab/mechanics/joint_actuator.gd")
const AnalyzerScript := preload("res://scripts/lab/mechanics/two_link_chain_analyzer.gd")
const CommandLedgerScript := preload("res://scripts/lab/command_ledger.gd")
const ActuationExecutorScript := preload("res://scripts/lab/actuation_executor.gd")
const ReceiptSinkScript := preload("res://scripts/lab/records/execution_receipt.gd")


func run(tree: SceneTree, contract: Dictionary, actuator_spec: Dictionary) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "TwoLink_%s" % String(contract["trial_id"])
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var world := Node3D.new()
	var root_body := _body(
		"chain_root",
		float(contract["root_mass_kg"]),
		_vector3(contract["root_size_m"]),
		Vector3(0.0, 2.0, 0.0)
	)
	var link_1_size := _vector3(contract["link_1_size_m"])
	var link_2_size := _vector3(contract["link_2_size_m"])
	var link_1 := _body(
		"link_1",
		float(contract["link_1_mass_kg"]),
		link_1_size,
		Vector3(link_1_size.x * 0.5, 2.0, 0.0)
	)
	var link_2 := _body(
		"link_2",
		float(contract["link_2_mass_kg"]),
		link_2_size,
		Vector3(link_1_size.x + link_2_size.x * 0.5, 2.0, 0.0)
	)
	root_body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	link_1.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	link_2.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	root_body.freeze = true
	link_1.freeze = true
	link_2.freeze = true
	world.add_child(root_body)
	world.add_child(link_1)
	world.add_child(link_2)
	var joint_1 := _hinge(Vector3(0.0, 2.0, 0.0))
	var joint_2 := _hinge(Vector3(link_1_size.x, 2.0, 0.0))
	world.add_child(joint_1)
	world.add_child(joint_2)
	viewport.add_child(world)
	joint_1.node_a = joint_1.get_path_to(root_body)
	joint_1.node_b = joint_1.get_path_to(link_1)
	joint_2.node_a = joint_2.get_path_to(link_1)
	joint_2.node_b = joint_2.get_path_to(link_2)
	var binding_1_build: Dictionary = JointBindingScript.build(
		_binding_configuration(
			"l2_6_joint_1",
			"chain_root",
			"link_1",
			Vector3.ZERO,
			Vector3(-link_1_size.x * 0.5, 0.0, 0.0),
			minf(_vector3(contract["root_size_m"]).x, link_1_size.x),
			String(contract["configuration_sha256"])
		)
	)
	var binding_2_build: Dictionary = JointBindingScript.build(
		_binding_configuration(
			"l2_6_joint_2",
			"link_1",
			"link_2",
			Vector3(link_1_size.x * 0.5, 0.0, 0.0),
			Vector3(-link_2_size.x * 0.5, 0.0, 0.0),
			minf(link_1_size.x, link_2_size.x),
			String(contract["configuration_sha256"])
		)
	)
	var binding_1: Dictionary = binding_1_build.get("binding", {})
	var binding_2: Dictionary = binding_2_build.get("binding", {})
	await tree.process_frame
	await tree.physics_frame
	if String(contract["root_mode"]) == "free":
		root_body.freeze = false
	link_1.freeze = false
	link_2.freeze = false
	await tree.physics_frame
	_reset_pose(root_body, link_1, link_2, link_1_size, link_2_size)
	var step_s := 1.0 / float(contract["physics_hz"])
	var states := _joint_states(
		binding_1, binding_2, root_body, link_1, link_2, String(contract["trial_id"]), 0, step_s
	)
	var initial_root_position := root_body.global_position
	var initial_com := _system_com(root_body, link_1, link_2)
	var samples: Array = []
	var previous_active_1 := 0.0
	var previous_active_2 := 0.0
	var previous_activation_1 := 1.0
	var previous_activation_2 := 1.0
	var receipt_sink = ReceiptSinkScript.new("l2_6_%s" % String(contract["trial_id"]))
	var bodies := {"chain_root": root_body, "link_1": link_1, "link_2": link_2}
	var fixture_complete := (
		bool(binding_1_build.get("ok", false))
		and bool(binding_2_build.get("ok", false))
		and bool((states["joint_1"] as Dictionary).get("observation_valid", false))
		and bool((states["joint_2"] as Dictionary).get("observation_valid", false))
	)
	for tick in int(contract["expected_sample_count"]):
		var request_1 := (
			float(contract["joint_1_torque_nm"]) if tick < int(contract["pulse_ticks"]) else 0.0
		)
		var request_2 := (
			float(contract["joint_2_torque_nm"]) if tick < int(contract["pulse_ticks"]) else 0.0
		)
		var state_1: Dictionary = states["joint_1"]
		var state_2: Dictionary = states["joint_2"]
		var plan_1: Dictionary = _plan(
			tick,
			"l2_6_joint_1",
			"chain_root",
			"link_1",
			state_1,
			request_1,
			previous_active_1,
			previous_activation_1,
			step_s,
			actuator_spec
		)
		var plan_2: Dictionary = _plan(
			tick,
			"l2_6_joint_2",
			"link_1",
			"link_2",
			state_2,
			request_2,
			previous_active_2,
			previous_activation_2,
			step_s,
			actuator_spec
		)
		fixture_complete = (
			bool(plan_1.get("ok", false)) and bool(plan_2.get("ok", false)) and fixture_complete
		)
		if not bool(plan_1.get("ok", false)) or not bool(plan_2.get("ok", false)):
			break
		var resolution_1: Dictionary = plan_1["resolution"]
		var resolution_2: Dictionary = plan_2["resolution"]
		var command_1: Dictionary = plan_1["command"]
		var command_2: Dictionary = plan_2["command"]
		var ledger = CommandLedgerScript.new()
		fixture_complete = ledger.begin_tick(tick) and fixture_complete
		fixture_complete = ledger.queue_joint(command_1) and fixture_complete
		fixture_complete = ledger.queue_joint(command_2) and fixture_complete
		var envelope: Dictionary = (
			ledger
			. seal(
				{
					"run_id": "l2_6_%s" % String(contract["trial_id"]),
					"command_id": tick,
					"source_frame_id": tick,
					"applied_transition": [tick, tick + 1],
					"mode": "L2_6_TWO_LINK_CHAIN",
				}
			)
		)
		var before_count := receipt_sink.values().size()
		var execution: Dictionary = ActuationExecutorScript.apply_command_envelope(
			envelope, bodies, receipt_sink
		)
		await tree.physics_frame
		var receipts: Array = receipt_sink.values().slice(before_count)
		var expected_operations: Array = []
		expected_operations.append_array(command_1["planned_application_operations"])
		expected_operations.append_array(command_2["planned_application_operations"])
		var receipts_match := _receipts_match(
			receipts, String(envelope["command_payload_sha256"]), expected_operations
		)
		states = _joint_states(
			binding_1,
			binding_2,
			root_body,
			link_1,
			link_2,
			String(contract["trial_id"]),
			tick + 1,
			step_s
		)
		state_1 = states["joint_1"]
		state_2 = states["joint_2"]
		fixture_complete = (
			bool(execution.get("ok", false))
			and int(execution.get("applied_count", -1)) == 4
			and receipts_match
			and bool(state_1.get("observation_valid", false))
			and bool(state_2.get("observation_valid", false))
			and fixture_complete
		)
		(
			samples
			. append(
				{
					"tick": tick,
					"requested_joint_1_nm": float(resolution_1["requested_active_nm"]),
					"applied_joint_1_nm": float(resolution_1["applied_total_nm"]),
					"requested_joint_2_nm": float(resolution_2["requested_active_nm"]),
					"applied_joint_2_nm": float(resolution_2["applied_total_nm"]),
					"joint_1_angle_rad": float(state_1["wrapped_angle_rad"]),
					"joint_1_rate_rad_s": float(state_1["axis_rate_rad_s"]),
					"joint_2_angle_rad": float(state_2["wrapped_angle_rad"]),
					"joint_2_rate_rad_s": float(state_2["axis_rate_rad_s"]),
					"joint_1_geometry_error": _geometry_error(state_1),
					"joint_2_geometry_error": _geometry_error(state_2),
					"max_pairing_residual_nm":
					maxf(
						float((command_1["diagnostics"] as Dictionary)["pairing_residual_nm"]),
						float((command_2["diagnostics"] as Dictionary)["pairing_residual_nm"])
					),
					"receipt_count": receipts.size(),
					"receipts_match_commands": receipts_match,
					"joint_1_observation_valid": bool(state_1["observation_valid"]),
					"joint_2_observation_valid": bool(state_2["observation_valid"]),
					"any_actuator_saturation":
					(
						bool(resolution_1["active_saturated"])
						or bool(resolution_1["torque_rate_limited"])
						or bool(resolution_1["structural_saturated"])
						or bool(resolution_2["active_saturated"])
						or bool(resolution_2["torque_rate_limited"])
						or bool(resolution_2["structural_saturated"])
					),
					"total_axis_angular_momentum_n_m_s":
					_total_angular_momentum(root_body, link_1, link_2),
					"system_com_displacement_m":
					_system_com(root_body, link_1, link_2).distance_to(initial_com),
					"root_displacement_m":
					root_body.global_position.distance_to(initial_root_position),
					"root_assistance_operation_count": 0,
					"root_operation_class": "joint_1_pair_reaction",
				}
			)
		)
		previous_active_1 = float(resolution_1["applied_active_nm"])
		previous_active_2 = float(resolution_2["applied_active_nm"])
		previous_activation_1 = float(resolution_1["activation_next"])
		previous_activation_2 = float(resolution_2["activation_next"])
	var analysis: Dictionary = AnalyzerScript.analyze(contract, samples)
	var result := {
		"fixture_complete":
		fixture_complete and samples.size() == int(contract["expected_sample_count"]),
		"analysis_ok": bool(analysis.get("ok", false)),
		"analysis_failure": {} if bool(analysis.get("ok", false)) else analysis,
		"result": analysis.get("result", {}),
		"samples": samples,
		"root_frozen": root_body.freeze,
		"motors_disabled":
		(
			not joint_1.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR)
			and not joint_2.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR)
		),
		"limits_disabled":
		(
			not joint_1.get_flag(HingeJoint3D.FLAG_USE_LIMIT)
			and not joint_2.get_flag(HingeJoint3D.FLAG_USE_LIMIT)
		),
	}
	viewport.queue_free()
	await tree.physics_frame
	return result


static func _plan(
	tick: int,
	joint_id: String,
	parent_id: String,
	child_id: String,
	state: Dictionary,
	request: float,
	previous_active: float,
	previous_activation: float,
	step_s: float,
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
				"source_id": "l2_6_two_link_pulse",
				"behavior_state": "DYNO",
				"axis_world": _vector3(state["current_axis_world"]),
				"pivot_world": _vector3(state["anchor_parent_world_m"]),
				"angular_velocity_rad_s": float(state["axis_rate_rad_s"]),
				"active_components": {"l2_6.pulse": request},
				"passive_components": {},
				"previous_active_nm": previous_active,
				"previous_activation": previous_activation,
				"step_s": step_s,
			},
			actuator_spec
		)
	)


static func _body(
	body_id: String, mass_kg: float, size_m: Vector3, position: Vector3
) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = body_id
	body.mass = mass_kg
	body.gravity_scale = 0.0
	body.can_sleep = false
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_m
	collision.shape = shape
	body.add_child(collision)
	return body


static func _hinge(position: Vector3) -> HingeJoint3D:
	var joint := HingeJoint3D.new()
	joint.position = position
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, false)
	return joint


static func _binding_configuration(
	joint_id: String,
	parent_id: String,
	child_id: String,
	parent_anchor: Vector3,
	child_anchor: Vector3,
	scale_m: float,
	configuration_sha256: String
) -> Dictionary:
	return {
		"joint_id": joint_id,
		"parent_body_id": parent_id,
		"child_body_id": child_id,
		"axis_parent_local": Vector3.BACK,
		"axis_child_local": Vector3.BACK,
		"anchor_parent_local": parent_anchor,
		"anchor_child_local": child_anchor,
		"rest_child_rotation_parent_local": Quaternion.IDENTITY,
		"anchor_agreement_tolerance_m": 5.0e-3,
		"axis_agreement_tolerance_rad": 2.0e-2,
		"swing_tolerance_rad": 2.0e-2,
		"local_joint_scale_m": scale_m,
		"local_joint_scale_basis": "joint_fixture_extent_min_v1",
		"morphology_config_digest_sha256": "sha256:%s" % configuration_sha256.sha256_text(),
		"requires_unwrapped_angle": false,
	}


static func _joint_states(
	binding_1: Dictionary,
	binding_2: Dictionary,
	root_body: RigidBody3D,
	link_1: RigidBody3D,
	link_2: RigidBody3D,
	trial_id: String,
	tick: int,
	step_s: float
) -> Dictionary:
	var root_sample := _body_sample("chain_root", trial_id, tick, step_s, root_body)
	var link_1_sample := _body_sample("link_1", trial_id, tick, step_s, link_1)
	var link_2_sample := _body_sample("link_2", trial_id, tick, step_s, link_2)
	return {
		"joint_1": JointStateScript.sample(binding_1, root_sample, link_1_sample),
		"joint_2": JointStateScript.sample(binding_2, link_1_sample, link_2_sample),
	}


static func _body_sample(
	body_id: String, trial_id: String, tick: int, step_s: float, body: RigidBody3D
) -> Dictionary:
	var transform := body.global_transform
	return {
		"schema_version": "mechanics_body_sample_v1",
		"physics_step_id": tick,
		"capture_epoch": tick,
		"sample_phase": "post_step",
		"step_s": step_s,
		"body_id": body_id,
		"run_id": "l2_6_%s" % trial_id,
		"capture_stream_id": "l2_6_two_link_chain",
		"observer_profile_id": "l2_6_joint_frames",
		"observer_adapter_id": "node_post_step_joint_chain_v1",
		"finite":
		(
			transform.origin.is_finite()
			and body.linear_velocity.is_finite()
			and body.angular_velocity.is_finite()
		),
		"transform":
		{
			"basis":
			[
				_vec(transform.basis.x),
				_vec(transform.basis.y),
				_vec(transform.basis.z),
			],
			"origin": _vec(transform.origin),
		},
		"linear_velocity": _vec(body.linear_velocity),
		"angular_velocity": _vec(body.angular_velocity),
	}


static func _reset_pose(
	root_body: RigidBody3D,
	link_1: RigidBody3D,
	link_2: RigidBody3D,
	link_1_size: Vector3,
	link_2_size: Vector3
) -> void:
	root_body.position = Vector3(0.0, 2.0, 0.0)
	link_1.position = Vector3(link_1_size.x * 0.5, 2.0, 0.0)
	link_2.position = Vector3(link_1_size.x + link_2_size.x * 0.5, 2.0, 0.0)
	for body in [root_body, link_1, link_2]:
		body.quaternion = Quaternion.IDENTITY
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO


static func _geometry_error(state: Dictionary) -> float:
	return maxf(
		float(state["anchor_agreement_error_m"]),
		maxf(
			float(state["axis_agreement_error_rad"]),
			maxf(float(state["swing_residual_rad"]), float(state["off_axis_rate_rad_s"]) * 0.01)
		)
	)


static func _system_com(a: RigidBody3D, b: RigidBody3D, c: RigidBody3D) -> Vector3:
	var total := a.mass + b.mass + c.mass
	return (
		(a.mass * a.global_position + b.mass * b.global_position + c.mass * c.global_position)
		/ total
	)


static func _total_angular_momentum(a: RigidBody3D, b: RigidBody3D, c: RigidBody3D) -> float:
	var total := 0.0
	for body in [a, b, c]:
		var collision := body.get_child(0) as CollisionShape3D
		var box := collision.shape as BoxShape3D
		var inertia_z: float = _box_axis_inertia(body.mass, box.size)
		var spin: float = inertia_z * body.angular_velocity.dot(Vector3.BACK)
		var orbital: float = body.global_position.cross(body.mass * body.linear_velocity).dot(
			Vector3.BACK
		)
		total += spin + orbital
	return total


static func _box_axis_inertia(mass_kg: float, size_m: Vector3) -> float:
	return mass_kg * (size_m.x * size_m.x + size_m.y * size_m.y) / 12.0


static func _receipts_match(receipts: Array, payload_hash: String, operations: Array) -> bool:
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


static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	var raw: Array = value
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))


static func _vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
