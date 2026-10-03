class_name LabFreeHingeEnvelopeRig
extends RefCounted

## Single live transition for one L2.4 actuator-envelope point.

const JointBindingScript := preload("res://scripts/lab/mechanics/joint_binding.gd")
const JointStateScript := preload("res://scripts/lab/mechanics/joint_state.gd")
const JointActuatorScript := preload("res://scripts/lab/mechanics/joint_actuator.gd")
const AnalyzerScript := preload("res://scripts/lab/mechanics/actuator_envelope_analyzer.gd")
const CommandLedgerScript := preload("res://scripts/lab/command_ledger.gd")
const ActuationExecutorScript := preload("res://scripts/lab/actuation_executor.gd")
const ReceiptSinkScript := preload("res://scripts/lab/records/execution_receipt.gd")


func run(tree: SceneTree, contract: Dictionary, actuator_spec: Dictionary) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "Envelope_%s" % String(contract["case_id"])
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var world := Node3D.new()
	var parent := _body(
		"rotor_parent", float(contract["parent_mass_kg"]), _vector3(contract["parent_size_m"])
	)
	var child := _body(
		"rotor_child", float(contract["child_mass_kg"]), _vector3(contract["child_size_m"])
	)
	parent.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	child.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	parent.freeze = true
	child.freeze = true
	world.add_child(parent)
	world.add_child(child)
	var joint := HingeJoint3D.new()
	joint.position = Vector3(0.0, 2.0, 0.0)
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, false)
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
	world.add_child(joint)
	viewport.add_child(world)
	joint.node_a = joint.get_path_to(parent)
	joint.node_b = joint.get_path_to(child)
	var binding_build: Dictionary = (
		JointBindingScript
		. build(
			{
				"joint_id": "l2_4_free_hinge_envelope",
				"parent_body_id": "rotor_parent",
				"child_body_id": "rotor_child",
				"axis_parent_local": Vector3.BACK,
				"axis_child_local": Vector3.BACK,
				"anchor_parent_local": Vector3.ZERO,
				"anchor_child_local": Vector3.ZERO,
				"rest_child_rotation_parent_local": Quaternion.IDENTITY,
				"anchor_agreement_tolerance_m": 5.0e-3,
				"axis_agreement_tolerance_rad": 2.0e-2,
				"swing_tolerance_rad": 2.0e-2,
				"local_joint_scale_m": 0.2,
				"local_joint_scale_basis": "joint_fixture_extent_min_v1",
				"morphology_config_digest_sha256":
				"sha256:%s" % String(contract["configuration_sha256"]).sha256_text(),
				"requires_unwrapped_angle": false,
			}
		)
	)
	var binding: Dictionary = binding_build.get("binding", {})
	await tree.process_frame
	await tree.physics_frame
	var parent_inertia := float(contract["analytic_parent_axis_inertia_kg_m2"])
	var child_inertia := float(contract["analytic_child_axis_inertia_kg_m2"])
	var relative_rate := float(contract["initial_relative_rate_rad_s"])
	var parent_rate := -child_inertia * relative_rate / (parent_inertia + child_inertia)
	var child_rate := parent_inertia * relative_rate / (parent_inertia + child_inertia)
	# Cross a dynamic activation tick before authoring the measured velocity
	# state. Velocities assigned while frozen are node properties but are not an
	# activated Jolt-space state.
	parent.freeze = false
	child.freeze = false
	await tree.physics_frame
	parent.position = Vector3(0.0, 2.0, 0.0)
	child.position = Vector3(0.0, 2.0, 0.0)
	parent.quaternion = Quaternion.IDENTITY
	child.quaternion = Quaternion.IDENTITY
	parent.angular_velocity = Vector3.BACK * parent_rate
	child.angular_velocity = Vector3.BACK * child_rate
	var step_s := 1.0 / float(contract["physics_hz"])
	var before_state := _joint_state(binding, parent, child, String(contract["case_id"]), 0, step_s)
	var axis := _vector3(before_state["current_axis_world"])
	var plan: Dictionary = (
		JointActuatorScript
		. resolve_and_plan(
			{
				"schema_version": "joint_actuator_input_v1",
				"tick": 0,
				"joint_id": "l2_4_free_hinge_envelope",
				"parent_body_id": "rotor_parent",
				"child_body_id": "rotor_child",
				"source_id": "l2_4_envelope_ramp",
				"behavior_state": "DYNO",
				"axis_world": axis,
				"pivot_world": Vector3(0.0, 2.0, 0.0),
				"angular_velocity_rad_s": relative_rate,
				"active_components": {"l2_4.ramp_request": float(contract["requested_torque_nm"])},
				"passive_components": {},
				"previous_active_nm": float(contract["requested_torque_nm"]),
				"previous_activation": 1.0,
				"step_s": step_s,
			},
			actuator_spec
		)
	)
	var fixture_complete := (
		bool(binding_build.get("ok", false))
		and bool(before_state.get("observation_valid", false))
		and bool(plan.get("ok", false))
	)
	var sample: Dictionary = {}
	if bool(plan.get("ok", false)):
		var resolution: Dictionary = plan["resolution"]
		var command: Dictionary = plan["command"]
		var ledger = CommandLedgerScript.new()
		fixture_complete = ledger.begin_tick(0) and fixture_complete
		fixture_complete = ledger.queue_joint(command) and fixture_complete
		var envelope: Dictionary = (
			ledger
			. seal(
				{
					"run_id": "l2_4_%s" % String(contract["case_id"]),
					"command_id": 0,
					"source_frame_id": 0,
					"applied_transition": [0, 1],
					"mode": "L2_4_ACTUATOR_ENVELOPE",
				}
			)
		)
		var receipt_sink = ReceiptSinkScript.new("l2_4_%s" % String(contract["case_id"]))
		var execution: Dictionary = ActuationExecutorScript.apply_command_envelope(
			envelope, {"rotor_parent": parent, "rotor_child": child}, receipt_sink
		)
		await tree.physics_frame
		var after_state := _joint_state(
			binding, parent, child, String(contract["case_id"]), 1, step_s
		)
		var receipts: Array = receipt_sink.values()
		var receipts_match := _receipts_match(
			receipts,
			String(envelope["command_payload_sha256"]),
			command["planned_application_operations"]
		)
		fixture_complete = (
			bool(execution.get("ok", false))
			and int(execution.get("applied_count", -1)) == 2
			and bool(after_state.get("observation_valid", false))
			and receipts_match
			and fixture_complete
		)
		sample = {
			"initial_relative_rate_rad_s": float(before_state["axis_rate_rad_s"]),
			"requested_torque_nm": float(resolution["requested_active_nm"]),
			"applied_torque_nm": float(resolution["applied_total_nm"]),
			"relative_rate_after_rad_s": float(after_state["axis_rate_rad_s"]),
			"selected_work_regime": String(resolution["selected_work_regime"]),
			"speed_limited": bool(resolution["speed_limited"]),
			"power_limited": bool(resolution["power_limited"]),
			"pairing_residual_nm":
			float((command["diagnostics"] as Dictionary)["pairing_residual_nm"]),
			"receipt_count": receipts.size(),
			"receipts_match_command": receipts_match,
			"joint_observation_valid": bool(after_state["observation_valid"]),
			"anchor_error_m": float(after_state["anchor_agreement_error_m"]),
			"axis_error_rad": float(after_state["axis_agreement_error_rad"]),
			"swing_residual_rad": float(after_state["swing_residual_rad"]),
			"off_axis_rate_rad_s": float(after_state["off_axis_rate_rad_s"]),
		}
	var analysis: Dictionary = AnalyzerScript.analyze(contract, sample)
	var result := {
		"fixture_complete": fixture_complete,
		"analysis_ok": bool(analysis.get("ok", false)),
		"analysis_failure": {} if bool(analysis.get("ok", false)) else analysis,
		"result": analysis.get("result", {}),
		"sample": sample,
		"motor_disabled": not joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR),
		"limit_disabled": not joint.get_flag(HingeJoint3D.FLAG_USE_LIMIT),
	}
	viewport.queue_free()
	await tree.physics_frame
	return result


static func _body(body_id: String, mass_kg: float, size_m: Vector3) -> RigidBody3D:
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
	body.position = Vector3(0.0, 2.0, 0.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_m
	collision.shape = shape
	body.add_child(collision)
	return body


static func _joint_state(
	binding: Dictionary,
	parent: RigidBody3D,
	child: RigidBody3D,
	case_id: String,
	tick: int,
	step_s: float
) -> Dictionary:
	return JointStateScript.sample(
		binding,
		_body_sample("rotor_parent", case_id, tick, step_s, parent),
		_body_sample("rotor_child", case_id, tick, step_s, child)
	)


static func _body_sample(
	body_id: String, case_id: String, tick: int, step_s: float, body: RigidBody3D
) -> Dictionary:
	var transform := body.global_transform
	return {
		"schema_version": "mechanics_body_sample_v1",
		"physics_step_id": tick,
		"capture_epoch": tick,
		"sample_phase": "post_step",
		"step_s": step_s,
		"body_id": body_id,
		"run_id": "l2_4_%s" % case_id,
		"capture_stream_id": "l2_4_free_hinge_envelope",
		"observer_profile_id": "l2_4_joint_frames",
		"observer_adapter_id": "node_post_step_joint_pair_v1",
		"finite": transform.origin.is_finite() and body.angular_velocity.is_finite(),
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
		"angular_velocity": _vec(body.angular_velocity),
	}


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
