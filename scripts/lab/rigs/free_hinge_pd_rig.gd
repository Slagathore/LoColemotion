class_name LabFreeHingePdRig
extends RefCounted

## Runtime fixture for the L2.2 unloaded, free-floating PD experiment.
##
## The rig owns scene construction and observation only. Controller resolution,
## actuator resolution, command hashing, mutation, and receipts remain separate
## evidence layers.

const ObservedRigidBodyScript := preload("res://scripts/lab/mechanics/observed_rigid_body.gd")
const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const MechanicsBodySampleScript := preload("res://scripts/lab/mechanics/mechanics_body_sample.gd")
const JointBindingScript := preload("res://scripts/lab/mechanics/joint_binding.gd")
const JointStateScript := preload("res://scripts/lab/mechanics/joint_state.gd")
const JointPdControllerScript := preload("res://scripts/lab/mechanics/joint_pd_controller.gd")
const JointActuatorScript := preload("res://scripts/lab/mechanics/joint_actuator.gd")
const PdAnalyzerScript := preload("res://scripts/lab/mechanics/unloaded_pd_step_analyzer.gd")
const CommandLedgerScript := preload("res://scripts/lab/command_ledger.gd")
const ActuationExecutorScript := preload("res://scripts/lab/actuation_executor.gd")
const ExecutionReceiptSinkScript := preload("res://scripts/lab/records/execution_receipt.gd")


func run(
	tree: SceneTree, contract: Dictionary, controller: Dictionary, actuator_spec: Dictionary
) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "FreeHingePd_%s" % String(contract["trial_id"])
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var world := Node3D.new()
	world.name = "FreeHingePdWorld"
	var clock = CaptureClockScript.new()
	var profile := {
		"profile_id": "l2_2_pd_joint_frames",
		"contacts_enabled": false,
		"contact_cap_per_body": 0,
		"channels": [],
	}
	var parent = _body(
		"rotor_parent",
		float(contract["parent_mass_kg"]),
		_vector3(contract["parent_size_m"]),
		clock,
		profile
	)
	var child = _body(
		"rotor_child",
		float(contract["child_mass_kg"]),
		_vector3(contract["child_size_m"]),
		clock,
		profile
	)
	world.add_child(parent)
	world.add_child(child)
	var joint := HingeJoint3D.new()
	joint.name = "FreeHingePd"
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
				"joint_id": "l2_2_free_hinge_pd",
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
	var fresh_world := viewport.own_world_3d and viewport.world_3d != tree.root.world_3d
	await tree.process_frame
	clock.open_epoch(0, 0.0, &"integrate_callback")
	await tree.physics_frame
	clock.close_epoch()
	var current_state := _joint_state(
		binding, parent.latest_body_sample, child.latest_body_sample, String(contract["trial_id"])
	)
	var fixture_complete := (
		fresh_world
		and bool(binding_build.get("ok", false))
		and bool(current_state.get("complete", false))
	)
	var samples: Array = []
	var previous_active := 0.0
	# The explicit laboratory actuator begins energized. This removes activation
	# dynamics from the L2.2 PD-identity experiment; activation dynamics remain
	# visible and separately testable in the actuator resolver.
	var previous_activation := 1.0
	var receipt_sink = ExecutionReceiptSinkScript.new("l2_2_%s" % String(contract["trial_id"]))
	var bodies := {
		"rotor_parent": parent,
		"rotor_child": child,
	}
	var step_s := 1.0 / float(contract["physics_hz"])
	for tick in int(contract["sample_ticks"]):
		if not bool(current_state.get("observation_valid", false)):
			fixture_complete = false
			break
		var axis := _vector3(current_state["current_axis_world"])
		var angle_before := float(current_state["wrapped_angle_rad"])
		var rate_before := float(current_state["axis_rate_rad_s"])
		var controller_result: Dictionary = (
			JointPdControllerScript
			. resolve(
				controller,
				{
					"schema_version": "joint_pd_controller_input_v1",
					"tick": tick,
					"target_angle_rad": float(contract["target_angle_rad"]),
					"measured_angle_rad": angle_before,
					"measured_rate_rad_s": rate_before,
				}
			)
		)
		fixture_complete = bool(controller_result.get("ok", false)) and fixture_complete
		if not bool(controller_result.get("ok", false)):
			break
		var pd: Dictionary = controller_result["resolution"]
		var parent_rate_before: float = parent.angular_velocity.dot(axis)
		var child_rate_before: float = child.angular_velocity.dot(axis)
		var plan: Dictionary = (
			JointActuatorScript
			. resolve_and_plan(
				{
					"schema_version": "joint_actuator_input_v1",
					"tick": tick,
					"joint_id": "l2_2_free_hinge_pd",
					"parent_body_id": "rotor_parent",
					"child_body_id": "rotor_child",
					"source_id": "l2_2_unloaded_pd",
					"behavior_state": "DYNO",
					"axis_world": axis,
					"pivot_world": Vector3(0.0, 2.0, 0.0),
					"angular_velocity_rad_s": rate_before,
					"active_components": pd["active_components"],
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
					"run_id": "l2_2_%s" % String(contract["trial_id"]),
					"command_id": tick,
					"source_frame_id": tick,
					"applied_transition": [tick, tick + 1],
					"mode": "L2_2_UNLOADED_PD",
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
			binding,
			parent.latest_body_sample,
			child.latest_body_sample,
			String(contract["trial_id"])
		)
		fixture_complete = (
			bool(execution.get("ok", false))
			and int(execution.get("applied_count", -1)) == 2
			and bool(current_state.get("complete", false))
			and new_receipts.size() == 2
			and receipts_match
			and fixture_complete
		)
		var post_axis := _vector3(current_state["current_axis_world"])
		(
			samples
			. append(
				{
					"tick": tick,
					"target_angle_rad": float(contract["target_angle_rad"]),
					"measured_angle_before_rad": angle_before,
					"measured_angle_after_rad": float(current_state["wrapped_angle_rad"]),
					"measured_rate_before_rad_s": rate_before,
					"measured_rate_after_rad_s": float(current_state["axis_rate_rad_s"]),
					"position_error_rad": float(pd["position_error_rad"]),
					"proportional_torque_nm": float(pd["proportional_torque_nm"]),
					"derivative_torque_nm": float(pd["derivative_torque_nm"]),
					"requested_torque_nm": float(pd["requested_torque_nm"]),
					"actuator_requested_torque_nm": float(resolution["requested_active_nm"]),
					"applied_torque_nm": float(resolution["applied_total_nm"]),
					"parent_rate_before_rad_s": parent_rate_before,
					"child_rate_before_rad_s": child_rate_before,
					"parent_rate_after_rad_s": parent.angular_velocity.dot(post_axis),
					"child_rate_after_rad_s": child.angular_velocity.dot(post_axis),
					"engine_parent_axis_inverse_inertia":
					_axis_inverse_inertia(parent.latest_body_sample, post_axis),
					"engine_child_axis_inverse_inertia":
					_axis_inverse_inertia(child.latest_body_sample, post_axis),
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
	var analysis: Dictionary = PdAnalyzerScript.analyze(contract, samples)
	var result := {
		"fixture_complete": fixture_complete and samples.size() == int(contract["sample_ticks"]),
		"analysis_ok": bool(analysis.get("ok", false)),
		"analysis_failure": {} if bool(analysis.get("ok", false)) else analysis,
		"result": analysis.get("result", {}),
		"samples": samples,
		"motor_disabled": not joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR),
		"limit_disabled": not joint.get_flag(HingeJoint3D.FLAG_USE_LIMIT),
		"gravity_disabled": parent.gravity_scale == 0.0 and child.gravity_scale == 0.0,
		"contact_disabled":
		(
			not parent.contact_monitor
			and not child.contact_monitor
			and parent.collision_mask == 0
			and child.collision_mask == 0
		),
	}
	viewport.queue_free()
	await tree.physics_frame
	return result


static func _body(body_id: String, mass_kg: float, size_m: Vector3, clock, profile: Dictionary):
	var body = ObservedRigidBodyScript.new()
	body.name = body_id
	body.body_id = StringName(body_id)
	body.part_index = 0 if body_id == "rotor_parent" else 1
	body.capture_clock = clock
	body.observer_profile = profile
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
	binding: Dictionary, parent_sample: Dictionary, child_sample: Dictionary, trial_id: String
) -> Dictionary:
	var run_id := "l2_2_%s" % trial_id
	var parent_projection: Dictionary = MechanicsBodySampleScript.project(
		parent_sample, run_id, "l2_2_free_hinge_capture"
	)
	var child_projection: Dictionary = MechanicsBodySampleScript.project(
		child_sample, run_id, "l2_2_free_hinge_capture"
	)
	if not bool(parent_projection.get("ok", false)) or not bool(child_projection.get("ok", false)):
		return {}
	return JointStateScript.sample(binding, parent_projection["sample"], child_projection["sample"])


static func _axis_inverse_inertia(body_sample: Dictionary, axis_world: Vector3) -> float:
	var inverse_tensor := _basis(body_sample["inverse_inertia_tensor_world"])
	return axis_world.dot(inverse_tensor * axis_world)


static func _basis(value: Dictionary) -> Basis:
	return Basis(_vector3(value["x"]), _vector3(value["y"]), _vector3(value["z"]))


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
