class_name LabFixedHingeGravityRig
extends RefCounted

## Live L2.3 fixed-scaffold, gravity-loaded single-link fixture.

const ObservedRigidBodyScript := preload("res://scripts/lab/mechanics/observed_rigid_body.gd")
const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const JointBindingScript := preload("res://scripts/lab/mechanics/joint_binding.gd")
const JointStateScript := preload("res://scripts/lab/mechanics/joint_state.gd")
const JointActuatorScript := preload("res://scripts/lab/mechanics/joint_actuator.gd")
const AnalyzerScript := preload("res://scripts/lab/mechanics/gravity_hold_analyzer.gd")
const CommandLedgerScript := preload("res://scripts/lab/command_ledger.gd")
const ActuationExecutorScript := preload("res://scripts/lab/actuation_executor.gd")
const ReceiptSinkScript := preload("res://scripts/lab/records/execution_receipt.gd")


func run(tree: SceneTree, contract: Dictionary, actuator_spec: Dictionary) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "FixedGravity_%s" % String(contract["trial_id"])
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var world := Node3D.new()
	world.name = "FixedGravityWorld"
	var clock = CaptureClockScript.new()
	var profile := {
		"profile_id": "l2_3_gravity_joint_frames",
		"contacts_enabled": false,
		"contact_cap_per_body": 0,
		"channels": [],
	}
	var parent = _body("fixed_parent", 1.0, Vector3(0.2, 0.2, 0.2), clock, profile, 0.0)
	parent.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	parent.freeze = true
	parent.position = Vector3(0.0, 2.0, 0.0)
	var link_size := Vector3(
		float(contract["link_length_m"]),
		float(contract["link_width_m"]),
		float(contract["link_depth_m"])
	)
	var child = _body(
		"loaded_link", float(contract["child_mass_kg"]), link_size, clock, profile, 1.0
	)
	child.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	child.freeze = true
	child.position = Vector3(float(contract["link_length_m"]) * 0.5, 2.0, 0.0)
	world.add_child(parent)
	world.add_child(child)
	var joint := HingeJoint3D.new()
	joint.name = "FixedGravityHinge"
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
				"joint_id": "l2_3_fixed_gravity_hinge",
				"parent_body_id": "fixed_parent",
				"child_body_id": "loaded_link",
				"axis_parent_local": Vector3.BACK,
				"axis_child_local": Vector3.BACK,
				"anchor_parent_local": Vector3.ZERO,
				"anchor_child_local": Vector3(-float(contract["link_length_m"]) * 0.5, 0.0, 0.0),
				"rest_child_rotation_parent_local": Quaternion.IDENTITY,
				"anchor_agreement_tolerance_m": 5.0e-3,
				"axis_agreement_tolerance_rad": 2.0e-2,
				"swing_tolerance_rad": 2.0e-2,
				"local_joint_scale_m": float(contract["link_length_m"]),
				"local_joint_scale_basis": "joint_fixture_extent_min_v1",
				"morphology_config_digest_sha256":
				"sha256:%s" % String(contract["configuration_sha256"]).sha256_text(),
				"requires_unwrapped_angle": false,
			}
		)
	)
	var binding: Dictionary = binding_build.get("binding", {})
	var fresh_world := viewport.own_world_3d and viewport.world_3d != tree.root.world_3d
	await tree.process_frame
	await tree.physics_frame
	parent.position = Vector3(0.0, 2.0, 0.0)
	parent.quaternion = Quaternion.IDENTITY
	child.position = Vector3(float(contract["link_length_m"]) * 0.5, 2.0, 0.0)
	child.quaternion = Quaternion.IDENTITY
	child.linear_velocity = Vector3.ZERO
	child.angular_velocity = Vector3.ZERO
	# Capture the authored horizontal pose while frozen. Measurement begins only
	# after this tagged activation sample has established complete joint frames.
	clock.open_epoch(0, 0.0, &"integrate_callback")
	await tree.physics_frame
	clock.close_epoch()
	var step_s := 1.0 / float(contract["physics_hz"])
	var current_state := _joint_state(
		binding, parent, child, String(contract["trial_id"]), 0, step_s
	)
	var fixture_complete := (
		fresh_world
		and bool(binding_build.get("ok", false))
		and bool(current_state.get("complete", false))
	)
	child.freeze = false
	var samples: Array = []
	var previous_active := 0.0
	var previous_activation := 1.0
	var receipt_sink = ReceiptSinkScript.new("l2_3_%s" % String(contract["trial_id"]))
	var bodies := {"fixed_parent": parent, "loaded_link": child}
	var request := float(contract["analytic_requested_compensation_nm"])
	for tick in int(contract["sample_ticks"]):
		var axis := _vector3(current_state["current_axis_world"])
		var angle_before := float(current_state["wrapped_angle_rad"])
		var rate_before := float(current_state["axis_rate_rad_s"])
		var plan: Dictionary = (
			JointActuatorScript
			. resolve_and_plan(
				{
					"schema_version": "joint_actuator_input_v1",
					"tick": tick,
					"joint_id": "l2_3_fixed_gravity_hinge",
					"parent_body_id": "fixed_parent",
					"child_body_id": "loaded_link",
					"source_id": "l2_3_gravity_compensation",
					"behavior_state": "DYNO",
					"axis_world": axis,
					"pivot_world": Vector3(0.0, 2.0, 0.0),
					"angular_velocity_rad_s": rate_before,
					"active_components": {"l2_3.gravity_compensation": request},
					"passive_components": {},
					"previous_active_nm": previous_active,
					"previous_activation": previous_activation,
					"step_s": step_s,
				},
				actuator_spec
			)
		)
		fixture_complete = bool(plan.get("ok", false)) and fixture_complete
		if not bool(plan.get("ok", false)):
			break
		var resolution: Dictionary = plan["resolution"]
		var command: Dictionary = plan["command"]
		var ledger = CommandLedgerScript.new()
		fixture_complete = ledger.begin_tick(tick) and fixture_complete
		fixture_complete = ledger.queue_joint(command) and fixture_complete
		var envelope: Dictionary = (
			ledger
			. seal(
				{
					"run_id": "l2_3_%s" % String(contract["trial_id"]),
					"command_id": tick,
					"source_frame_id": tick,
					"applied_transition": [tick, tick + 1],
					"mode": "L2_3_GRAVITY_HOLD",
				}
			)
		)
		var receipt_count_before := receipt_sink.values().size()
		clock.open_epoch(tick + 1, float(tick + 1) * step_s, &"integrate_callback")
		var execution: Dictionary = ActuationExecutorScript.apply_command_envelope(
			envelope, bodies, receipt_sink
		)
		await tree.physics_frame
		clock.close_epoch()
		var all_receipts: Array = receipt_sink.values()
		var new_receipts := all_receipts.slice(receipt_count_before)
		var receipts_match := _receipts_match(
			new_receipts,
			String(envelope["command_payload_sha256"]),
			command["planned_application_operations"]
		)
		current_state = _joint_state(
			binding, parent, child, String(contract["trial_id"]), tick + 1, step_s
		)
		fixture_complete = (
			bool(execution.get("ok", false))
			and int(execution.get("applied_count", -1)) == 2
			and bool(current_state.get("complete", false))
			and receipts_match
			and fixture_complete
		)
		(
			samples
			. append(
				{
					"tick": tick,
					"requested_torque_nm": float(resolution["requested_active_nm"]),
					"applied_torque_nm": float(resolution["applied_total_nm"]),
					"angle_before_rad": angle_before,
					"angle_after_rad": float(current_state["wrapped_angle_rad"]),
					"rate_before_rad_s": rate_before,
					"rate_after_rad_s": float(current_state["axis_rate_rad_s"]),
					"pairing_residual_nm":
					float((command["diagnostics"] as Dictionary)["pairing_residual_nm"]),
					"receipt_count": new_receipts.size(),
					"receipts_match_command": receipts_match,
					"joint_observation_valid": bool(current_state["observation_valid"]),
					"anchor_error_m": float(current_state["anchor_agreement_error_m"]),
					"axis_error_rad": float(current_state["axis_agreement_error_rad"]),
					"swing_residual_rad": float(current_state["swing_residual_rad"]),
					"off_axis_rate_rad_s": float(current_state["off_axis_rate_rad_s"]),
					"active_saturated": bool(resolution["active_saturated"]),
					"torque_rate_limited": bool(resolution["torque_rate_limited"]),
					"structural_saturated": bool(resolution["structural_saturated"]),
				}
			)
		)
		previous_active = float(resolution["applied_active_nm"])
		previous_activation = float(resolution["activation_next"])
	var analysis: Dictionary = AnalyzerScript.analyze(contract, samples)
	var result := {
		"fixture_complete": fixture_complete and samples.size() == int(contract["sample_ticks"]),
		"analysis_ok": bool(analysis.get("ok", false)),
		"analysis_failure": {} if bool(analysis.get("ok", false)) else analysis,
		"result": analysis.get("result", {}),
		"samples": samples,
		"parent_frozen": parent.freeze,
		"motor_disabled": not joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR),
		"limit_disabled": not joint.get_flag(HingeJoint3D.FLAG_USE_LIMIT),
		"contact_disabled": child.collision_mask == 0 and parent.collision_mask == 0,
	}
	viewport.queue_free()
	await tree.physics_frame
	return result


static func _body(
	body_id: String,
	mass_kg: float,
	size_m: Vector3,
	clock,
	profile: Dictionary,
	gravity_scale: float
):
	var body = ObservedRigidBodyScript.new()
	body.name = body_id
	body.body_id = StringName(body_id)
	body.part_index = 0 if body_id == "fixed_parent" else 1
	body.capture_clock = clock
	body.observer_profile = profile
	body.mass = mass_kg
	body.gravity_scale = gravity_scale
	body.can_sleep = false
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.collision_layer = 1
	body.collision_mask = 0
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
	trial_id: String,
	tick: int,
	step_s: float
) -> Dictionary:
	return JointStateScript.sample(
		binding,
		_body_sample(
			"fixed_parent", trial_id, tick, step_s, parent.global_transform, parent.angular_velocity
		),
		_body_sample(
			"loaded_link", trial_id, tick, step_s, child.global_transform, child.angular_velocity
		)
	)


static func _body_sample(
	body_id: String,
	trial_id: String,
	tick: int,
	step_s: float,
	transform: Transform3D,
	angular_velocity: Vector3
) -> Dictionary:
	return {
		"schema_version": "mechanics_body_sample_v1",
		"physics_step_id": tick,
		"capture_epoch": tick,
		"sample_phase": "post_step",
		"step_s": step_s,
		"body_id": body_id,
		"run_id": "l2_3_%s" % trial_id,
		"capture_stream_id": "l2_3_fixed_gravity_capture",
		"observer_profile_id": "l2_3_gravity_joint_frames",
		"observer_adapter_id": "node_post_step_joint_pair_v1",
		"finite":
		(
			transform.origin.is_finite()
			and transform.basis.x.is_finite()
			and transform.basis.y.is_finite()
			and transform.basis.z.is_finite()
			and angular_velocity.is_finite()
		),
		"transform":
		{
			"basis":
			[
				_vector3_array(transform.basis.x),
				_vector3_array(transform.basis.y),
				_vector3_array(transform.basis.z),
			],
			"origin": _vector3_array(transform.origin),
		},
		"angular_velocity": _vector3_array(angular_velocity),
	}


static func _vector3_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


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
