class_name LabFreeHingeLimitRig
extends RefCounted

## Runtime fixture for L2.5 hard-limit approach and disabled-limit control.

const JointBindingScript := preload("res://scripts/lab/mechanics/joint_binding.gd")
const JointStateScript := preload("res://scripts/lab/mechanics/joint_state.gd")
const AnalyzerScript := preload("res://scripts/lab/mechanics/hard_limit_reaction_analyzer.gd")


func run(tree: SceneTree, contract: Dictionary) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "HardLimit_%s" % String(contract["trial_id"])
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
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, bool(contract["limit_enabled"]))
	joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, float(contract["lower_limit_rad"]))
	joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, float(contract["upper_limit_rad"]))
	world.add_child(joint)
	viewport.add_child(world)
	joint.node_a = joint.get_path_to(parent)
	joint.node_b = joint.get_path_to(child)
	var binding_build: Dictionary = (
		JointBindingScript
		. build(
			{
				"joint_id": "l2_5_free_hinge_limit",
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
	parent.freeze = false
	child.freeze = false
	await tree.physics_frame
	var parent_inertia := _box_axis_inertia(
		float(contract["parent_mass_kg"]), _vector3(contract["parent_size_m"])
	)
	var child_inertia := _box_axis_inertia(
		float(contract["child_mass_kg"]), _vector3(contract["child_size_m"])
	)
	var relative_rate := float(contract["initial_relative_rate_rad_s"])
	var parent_rate := -child_inertia * relative_rate / (parent_inertia + child_inertia)
	var child_rate := parent_inertia * relative_rate / (parent_inertia + child_inertia)
	parent.position = Vector3(0.0, 2.0, 0.0)
	child.position = Vector3(0.0, 2.0, 0.0)
	parent.quaternion = Quaternion.IDENTITY
	child.quaternion = Quaternion.IDENTITY
	parent.angular_velocity = Vector3.BACK * parent_rate
	child.angular_velocity = Vector3.BACK * child_rate
	var step_s := 1.0 / float(contract["physics_hz"])
	var state := _joint_state(binding, parent, child, String(contract["trial_id"]), 0, step_s)
	var samples: Array = []
	var fixture_complete := (
		bool(binding_build.get("ok", false)) and bool(state.get("observation_valid", false))
	)
	for tick in int(contract["sample_ticks"]):
		var angle_before := float(state["wrapped_angle_rad"])
		var rate_before := float(state["axis_rate_rad_s"])
		await tree.physics_frame
		state = _joint_state(binding, parent, child, String(contract["trial_id"]), tick + 1, step_s)
		fixture_complete = bool(state.get("observation_valid", false)) and fixture_complete
		var axis := _vector3(state["current_axis_world"])
		(
			samples
			. append(
				{
					"tick": tick,
					"angle_before_rad": angle_before,
					"angle_after_rad": float(state["wrapped_angle_rad"]),
					"relative_rate_before_rad_s": rate_before,
					"relative_rate_after_rad_s": float(state["axis_rate_rad_s"]),
					"parent_rate_after_rad_s": parent.angular_velocity.dot(axis),
					"child_rate_after_rad_s": child.angular_velocity.dot(axis),
					"parent_axis_inertia_kg_m2": parent_inertia,
					"child_axis_inertia_kg_m2": child_inertia,
					"active_torque_nm": 0.0,
					"passive_torque_nm": 0.0,
					"command_count": 0,
					"joint_observation_valid": bool(state["observation_valid"]),
					"anchor_error_m": float(state["anchor_agreement_error_m"]),
					"axis_error_rad": float(state["axis_agreement_error_rad"]),
					"swing_residual_rad": float(state["swing_residual_rad"]),
					"off_axis_rate_rad_s": float(state["off_axis_rate_rad_s"]),
				}
			)
		)
	var analysis: Dictionary = AnalyzerScript.analyze(contract, samples)
	var result := {
		"fixture_complete": fixture_complete and samples.size() == int(contract["sample_ticks"]),
		"analysis_ok": bool(analysis.get("ok", false)),
		"analysis_failure": {} if bool(analysis.get("ok", false)) else analysis,
		"result": analysis.get("result", {}),
		"samples": samples,
		"motor_disabled": not joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR),
		"limit_enabled": joint.get_flag(HingeJoint3D.FLAG_USE_LIMIT),
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
	trial_id: String,
	tick: int,
	step_s: float
) -> Dictionary:
	return JointStateScript.sample(
		binding,
		_body_sample("rotor_parent", trial_id, tick, step_s, parent),
		_body_sample("rotor_child", trial_id, tick, step_s, child)
	)


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
		"run_id": "l2_5_%s" % trial_id,
		"capture_stream_id": "l2_5_free_hinge_limit",
		"observer_profile_id": "l2_5_joint_frames",
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


static func _box_axis_inertia(mass_kg: float, size_m: Vector3) -> float:
	return mass_kg * (size_m.x * size_m.x + size_m.y * size_m.y) / 12.0


static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	var raw: Array = value
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))


static func _vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
