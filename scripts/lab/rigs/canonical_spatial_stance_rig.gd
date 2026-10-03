class_name LabCanonicalSpatialStanceRig
extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## BR14A.3 first free-3D physical stance fixture for the exact selected
## quadruped profile.
##
## The only static collision object is the ordinary floor. There is no root
## pin, world anchor, rail, gimbal, guide, freeze after release, built-in
## joint motor, or spring. Every active torque is an equal/opposite
## LabJointActuator command sealed by LabCommandLedger and applied by
## LabActuationExecutor.

const ActuationExecutorScript := preload("res://scripts/lab/actuation_executor.gd")
const ActuatorSpecScript := preload("res://scripts/lab/mechanics/actuator_spec.gd")
const CommandLedgerScript := preload("res://scripts/lab/command_ledger.gd")
const JointActuatorScript := preload("res://scripts/lab/mechanics/joint_actuator.gd")
const ReceiptSinkScript := preload("res://scripts/lab/records/execution_receipt.gd")
const SemanticContactBodyScript := preload(
	"res://scripts/lab/mechanics/semantic_contact_rigid_body.gd"
)

const LAB_COLLISION_LAYER := 1 << 20
const FLOOR_ID := "br14a_floor"
const TORSO_ID := "br14a_torso"


func run_trial(
	tree: SceneTree,
	profile: Dictionary,
	experiment: Dictionary,
	seed: int,
	controller_enabled: bool
) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "BR14A_Stance_%d_%s" % [seed, "active" if controller_enabled else "control"]
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var world := Node3D.new()
	world.name = "BR14ACanonicalSpatialStanceWorld"
	var floor := _build_floor(float(profile["contact_friction_coefficient"]))
	var torso := _build_torso(profile["torso"])
	var body_by_id: Dictionary = {TORSO_ID: torso}
	var limbs: Array = []
	var joint_nodes: Array[Joint3D] = []
	for limb_value in profile["limbs"]:
		var limb := _build_limb(limb_value, float(profile["contact_friction_coefficient"]))
		torso.add_collision_exception_with(limb["upper"])
		(limb["upper"] as RigidBody3D).add_collision_exception_with(torso)
		limbs.append(limb)
		body_by_id[String(limb["upper_id"])] = limb["upper"]
		body_by_id[String(limb["lower_id"])] = limb["lower"]
		joint_nodes.append(limb["hip_joint"])
		joint_nodes.append(limb["knee_joint"])
	for node in [torso, floor]:
		world.add_child(node)
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		for node in [
			limb["upper"],
			limb["lower"],
			limb["hip_joint"],
			limb["knee_joint"],
		]:
			world.add_child(node)
	viewport.add_child(world)
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var hip: Generic6DOFJoint3D = limb["hip_joint"]
		var knee: HingeJoint3D = limb["knee_joint"]
		hip.node_a = hip.get_path_to(torso)
		hip.node_b = hip.get_path_to(limb["upper"])
		knee.node_a = knee.get_path_to(limb["upper"])
		knee.node_b = knee.get_path_to(limb["lower"])
	await tree.process_frame
	await tree.physics_frame
	_capture_rest_state(torso, limbs)
	for body_value in body_by_id.values():
		var body: RigidBody3D = body_value
		body.freeze = false
		body.sleeping = false
	var perturbation := float((seed % 3) - 1) * 0.008
	torso.angular_velocity = Vector3(perturbation, 0.0, -0.5 * perturbation)
	await tree.physics_frame

	var receipt_sink = ReceiptSinkScript.new(
		"br14a_stance_%d_%s" % [seed, "active" if controller_enabled else "control"]
	)
	var trial_ticks := int(experiment["trial_ticks"])
	var dwell_ticks_required := int(experiment["dwell_ticks_required"])
	var step_s := 1.0 / float(profile["physics_hz"])
	var fixture_complete := true
	var fixture_failure_code := ""
	var all_receipts_complete := true
	var maximum_pairing_residual_nm := 0.0
	var maximum_applied_torque_nm := 0.0
	var actuator_saturation_count := 0
	var active_envelope_clamp_count := 0
	var torque_rate_limit_count := 0
	var structural_saturation_count := 0
	var active_command_count := 0
	var contact_ticks: Dictionary = {}
	for limb_value in limbs:
		contact_ticks[String((limb_value as Dictionary)["contact_id"])] = 0
	var torso_contact_ticks := 0
	var maximum_anchor_error_m := 0.0
	var maximum_axis_error_rad := 0.0
	var maximum_tilt_rad := _tilt(torso)
	var maximum_height_error_m := absf(
		torso.global_position.y - float(profile["torso"]["center_world_m"][1])
	)
	var stable_dwell_ticks := 0
	var longest_stable_dwell_ticks := 0
	var final_all_feet_bearing := false
	for tick in range(trial_ticks):
		var all_feet_bearing := true
		for limb_value in limbs:
			var limb: Dictionary = limb_value
			var lower: RigidBody3D = limb["lower"]
			var bearing := floor in lower.get_colliding_bodies()
			all_feet_bearing = all_feet_bearing and bearing
			if bearing:
				var contact_id := String(limb["contact_id"])
				contact_ticks[contact_id] = int(contact_ticks[contact_id]) + 1
		if floor in torso.get_colliding_bodies():
			torso_contact_ticks += 1
		final_all_feet_bearing = all_feet_bearing
		for limb_value in limbs:
			var geometry := _joint_geometry_diagnostics(torso, limb_value)
			maximum_anchor_error_m = maxf(
				maximum_anchor_error_m, float(geometry["maximum_anchor_error_m"])
			)
			maximum_axis_error_rad = maxf(
				maximum_axis_error_rad, float(geometry["maximum_axis_error_rad"])
			)
		var command_result := _command_tick(
			tick, limbs, body_by_id, profile, experiment, receipt_sink, controller_enabled, step_s
		)
		if not bool(command_result.get("ok", false)):
			fixture_complete = false
			fixture_failure_code = String(
				command_result.get("failure_code", "SPATIAL_STANCE_COMMAND_FAILED")
			)
			break
		all_receipts_complete = (
			all_receipts_complete and bool(command_result["receipts_complete"])
		)
		maximum_pairing_residual_nm = maxf(
			maximum_pairing_residual_nm, float(command_result["maximum_pairing_residual_nm"])
		)
		maximum_applied_torque_nm = maxf(
			maximum_applied_torque_nm, float(command_result["maximum_applied_torque_nm"])
		)
		actuator_saturation_count += int(command_result["actuator_saturation_count"])
		active_envelope_clamp_count += int(command_result["active_envelope_clamp_count"])
		torque_rate_limit_count += int(command_result["torque_rate_limit_count"])
		structural_saturation_count += int(command_result["structural_saturation_count"])
		active_command_count += int(command_result["active_command_count"])
		await tree.physics_frame
		var tilt := _tilt(torso)
		var height_error := absf(
			torso.global_position.y - float(profile["torso"]["center_world_m"][1])
		)
		maximum_tilt_rad = maxf(maximum_tilt_rad, tilt)
		maximum_height_error_m = maxf(maximum_height_error_m, height_error)
		var stable := (
			all_feet_bearing
			and not (floor in torso.get_colliding_bodies())
			and height_error <= float(experiment["height_error_limit_m"])
			and tilt <= float(experiment["tilt_limit_rad"])
			and torso.linear_velocity.length() <= float(experiment["linear_speed_limit_m_s"])
			and torso.angular_velocity.length() <= float(experiment["angular_speed_limit_rad_s"])
		)
		if stable:
			stable_dwell_ticks += 1
			longest_stable_dwell_ticks = maxi(longest_stable_dwell_ticks, stable_dwell_ticks)
		else:
			stable_dwell_ticks = 0

	var final_tilt_rad := _tilt(torso)
	var final_height_error_m := absf(
		torso.global_position.y - float(profile["torso"]["center_world_m"][1])
	)
	var final_linear_speed_m_s := torso.linear_velocity.length()
	var final_angular_speed_rad_s := torso.angular_velocity.length()
	var contact_fractions: Dictionary = {}
	for contact_id in contact_ticks:
		contact_fractions[contact_id] = float(contact_ticks[contact_id]) / float(trial_ticks)
	var summary := {
		"schema_version": "canonical_spatial_stance_summary_v1",
		"profile_id": profile["profile_id"],
		"profile_sha256": profile["profile_sha256"],
		"experiment_id": experiment["experiment_id"],
		"experiment_sha256": experiment["experiment_sha256"],
		"controller_id": experiment["controller_id"],
		"seed": seed,
		"controller_enabled": controller_enabled,
		"fixture_complete": fixture_complete,
		"fixture_failure_code": fixture_failure_code,
		"physics_hz": profile["physics_hz"],
		"trial_ticks": trial_ticks,
		"dwell_ticks_required": dwell_ticks_required,
		"body_count": body_by_id.size(),
		"physical_limb_count": limbs.size(),
		"actuated_dof_count": 12,
		"joint_node_count": joint_nodes.size(),
		"static_body_count": 1,
		"only_static_body_is_ordinary_floor": true,
		"world_anchor_count": 0,
		"root_pin_count": 0,
		"rail_count": 0,
		"guide_count": 0,
		"gimbal_count": 0,
		"built_in_joint_motor_count": 0,
		"joint_spring_count": 0,
		"freeze_operation_count_after_release": 0,
		"root_force_or_torque_operation_count": 0,
		"foot_pin_operation_count": 0,
		"pose_teleport_operation_count": 0,
		"automatic_creature_guidance_operation_count": 0,
		"active_command_count": active_command_count,
		"all_receipts_complete": all_receipts_complete,
		"maximum_pairing_residual_nm": maximum_pairing_residual_nm,
		"maximum_applied_torque_nm": maximum_applied_torque_nm,
		"actuator_saturation_count": actuator_saturation_count,
		"active_envelope_clamp_count": active_envelope_clamp_count,
		"torque_rate_limit_count": torque_rate_limit_count,
		"structural_saturation_count": structural_saturation_count,
		"maximum_anchor_error_m": maximum_anchor_error_m,
		"maximum_hinge_axis_error_rad": maximum_axis_error_rad,
		"maximum_tilt_rad": maximum_tilt_rad,
		"maximum_height_error_m": maximum_height_error_m,
		"final_torso_height_m": torso.global_position.y,
		"final_height_error_m": final_height_error_m,
		"final_tilt_rad": final_tilt_rad,
		"final_linear_speed_m_s": final_linear_speed_m_s,
		"final_angular_speed_rad_s": final_angular_speed_rad_s,
		"final_all_feet_bearing": final_all_feet_bearing,
		"torso_contact_ticks": torso_contact_ticks,
		"contact_fractions": contact_fractions,
		"longest_stable_dwell_ticks": longest_stable_dwell_ticks,
		"stance_dwell_observed":
		longest_stable_dwell_ticks >= dwell_ticks_required and final_all_feet_bearing,
		"per_contact_commands_are_measurements": false,
		"per_foot_measured_load_allocation_available": false,
		"free_3d_static_stance_established": false,
		"free_3d_recovery_established": false,
		"step_gait_or_walking_established": false,
		"automatic_creature_guidance_allowed": false,
	}
	viewport.queue_free()
	await tree.physics_frame
	await tree.process_frame
	return {"ok": fixture_complete, "summary": summary}


static func _build_torso(configuration: Dictionary) -> RigidBody3D:
	var body := _body(
		TORSO_ID, float(configuration["mass_kg"]), _vector3(configuration["center_world_m"])
	)
	_add_box(body, _vector3(configuration["size_m"]), Vector3.ZERO, "torso_shape")
	return body


static func _build_limb(configuration: Dictionary, friction: float) -> Dictionary:
	var limb_id := String(configuration["limb_id"])
	var hip := _vector3(configuration["hip_world_m"])
	var knee := _vector3(configuration["knee_world_m"])
	var foot := _vector3(configuration["foot_center_world_m"])
	var upper_id := "br14a_%s_upper" % limb_id
	var lower_id := "br14a_%s_lower" % limb_id
	var upper := _build_link(
		upper_id,
		hip,
		knee,
		float(configuration["upper_mass_kg"]),
		float(configuration["foot_radius_m"]),
		false,
		friction
	)
	var lower := _build_link(
		lower_id,
		knee,
		foot,
		float(configuration["lower_mass_kg"]),
		float(configuration["foot_radius_m"]),
		true,
		friction
	)
	upper.add_collision_exception_with(lower)
	lower.add_collision_exception_with(upper)
	var hip_joint := _build_hip_joint(configuration)
	var knee_joint := _build_knee_joint(configuration)
	var joint_states: Array = []
	for joint_value in configuration["joint_dofs"]:
		var joint: Dictionary = joint_value
		(
			joint_states
			. append(
				{
					"joint_id": joint["joint_id"],
					"role": joint["role"],
					"axis_world_initial": joint["axis_world"],
					"pivot_world_initial": joint["pivot_world_m"],
					"minimum_angle_rad": joint["minimum_angle_rad"],
					"maximum_angle_rad": joint["maximum_angle_rad"],
					"parent_id":
					TORSO_ID if String(joint["role"]).begins_with("hip_") else upper_id,
					"child_id": upper_id if String(joint["role"]).begins_with("hip_") else lower_id,
					"previous_active_nm": 0.0,
					"previous_activation": 1.0,
				}
			)
		)
	return {
		"limb_id": limb_id,
		"contact_id": "%s.foot" % limb_id,
		"configuration": configuration,
		"upper_id": upper_id,
		"lower_id": lower_id,
		"upper": upper,
		"lower": lower,
		"hip_joint": hip_joint,
		"knee_joint": knee_joint,
		"joint_states": joint_states,
	}


static func _build_link(
	body_id: String,
	proximal: Vector3,
	distal: Vector3,
	mass_kg: float,
	foot_radius: float,
	has_foot: bool,
	friction: float
) -> RigidBody3D:
	var direction := (distal - proximal).normalized()
	var length := proximal.distance_to(distal)
	var body := _body(body_id, mass_kg, 0.5 * (proximal + distal))
	body.quaternion = Quaternion(Vector3.RIGHT, direction)
	var shaft_length := length - (2.0 * foot_radius if has_foot else 0.02)
	_add_box(body, Vector3(shaft_length, 0.035, 0.035), Vector3.ZERO, "%s_shaft" % body_id)
	if has_foot:
		var foot := CollisionShape3D.new()
		foot.name = "%s_foot" % body_id
		foot.set_meta("lab_shape_id", "%s_foot" % body_id)
		foot.position = Vector3(length * 0.5, 0.0, 0.0)
		var sphere := SphereShape3D.new()
		sphere.radius = foot_radius
		foot.shape = sphere
		body.add_child(foot)
	body.physics_material_override = _material(friction)
	return body


static func _build_hip_joint(configuration: Dictionary) -> Generic6DOFJoint3D:
	var joint := Generic6DOFJoint3D.new()
	joint.name = "br14a_%s_hip" % String(configuration["limb_id"])
	joint.position = _vector3(configuration["hip_world_m"])
	var abduction_axis := _joint_axis(configuration, "hip_abduction")
	var pitch_axis := _joint_axis(configuration, "hip_pitch")
	var y_axis := pitch_axis.cross(abduction_axis).normalized()
	joint.basis = Basis(abduction_axis, y_axis, pitch_axis)
	for axis in ["x", "y", "z"]:
		joint.set("linear_limit_%s/enabled" % axis, true)
		joint.set("linear_limit_%s/lower_distance" % axis, 0.0)
		joint.set("linear_limit_%s/upper_distance" % axis, 0.0)
		joint.set("linear_motor_%s/enabled" % axis, false)
		joint.set("linear_spring_%s/enabled" % axis, false)
		joint.set("angular_limit_%s/enabled" % axis, true)
		joint.set("angular_limit_%s/lower_angle" % axis, -0.8 if axis != "y" else 0.0)
		joint.set("angular_limit_%s/upper_angle" % axis, 0.8 if axis != "y" else 0.0)
		joint.set("angular_motor_%s/enabled" % axis, false)
		joint.set("angular_spring_%s/enabled" % axis, false)
	return joint


static func _build_knee_joint(configuration: Dictionary) -> HingeJoint3D:
	var joint := HingeJoint3D.new()
	joint.name = "br14a_%s_knee" % String(configuration["limb_id"])
	var hip := _vector3(configuration["hip_world_m"])
	var knee := _vector3(configuration["knee_world_m"])
	var upper_direction := (knee - hip).normalized()
	var pitch_axis := _joint_axis(configuration, "knee_pitch")
	var y_axis := pitch_axis.cross(upper_direction).normalized()
	joint.position = knee
	joint.basis = Basis(upper_direction, y_axis, pitch_axis)
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, -0.8)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, 0.8)
	return joint


static func _capture_rest_state(torso: RigidBody3D, limbs: Array) -> void:
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var upper: RigidBody3D = limb["upper"]
		var lower: RigidBody3D = limb["lower"]
		for state_value in limb["joint_states"]:
			var state: Dictionary = state_value
			var parent: RigidBody3D = torso if String(state["parent_id"]) == TORSO_ID else upper
			var child: RigidBody3D = (
				upper if String(state["child_id"]) == String(limb["upper_id"]) else lower
			)
			state["desired_relative_basis"] = parent.global_basis.inverse() * child.global_basis
			state["axis_parent_local"] = (
				(parent.global_basis.inverse() * _vector3(state["axis_world_initial"])).normalized()
			)
			state["axis_child_local"] = (
				(child.global_basis.inverse() * _vector3(state["axis_world_initial"])).normalized()
			)
			var pivot := _vector3(state["pivot_world_initial"])
			state["anchor_parent_local"] = parent.to_local(pivot)
			state["anchor_child_local"] = child.to_local(pivot)


static func _command_tick(
	tick: int,
	limbs: Array,
	body_by_id: Dictionary,
	profile: Dictionary,
	experiment: Dictionary,
	receipt_sink: RefCounted,
	controller_enabled: bool,
	step_s: float,
	pose_feedback_enabled: bool = true,
	joint_torque_overrides: Dictionary = {},
	joint_torque_additions: Dictionary = {},
	joint_torque_override_blend_fraction: float = 1.0
) -> Dictionary:
	if not controller_enabled:
		return {
			"ok": true,
			"receipts_complete": true,
			"maximum_pairing_residual_nm": 0.0,
			"maximum_applied_torque_nm": 0.0,
			"actuator_saturation_count": 0,
			"active_envelope_clamp_count": 0,
			"torque_rate_limit_count": 0,
			"structural_saturation_count": 0,
			"active_command_count": 0,
		}
	var plans: Array = []
	var resolutions: Array = []
	var state_order: Array = []
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		for state_value in limb["joint_states"]:
			var state: Dictionary = state_value
			var parent: RigidBody3D = body_by_id[String(state["parent_id"])]
			var child: RigidBody3D = body_by_id[String(state["child_id"])]
			var axis_world := (
				(parent.global_basis * _vector3(state["axis_parent_local"])).normalized()
			)
			var error_world := _orientation_error_world(
				parent, child, state["desired_relative_basis"]
			)
			var error := error_world.dot(axis_world)
			var rate := (child.angular_velocity - parent.angular_velocity).dot(axis_world)
			var feedforward := _static_feedforward_nm(profile, limb, state)
			var requested := (
				feedforward
				+ (
					(
						float(experiment["position_gain_nm_per_rad"]) * error
						- float(experiment["velocity_gain_nm_s_per_rad"]) * rate
					)
					if pose_feedback_enabled
					else 0.0
				)
			)
			var active_components := {
				"br14a.static_feedforward": feedforward,
				"br14a.relative_pose_tracking": requested - feedforward,
			}
			if joint_torque_overrides.has(String(state["joint_id"])):
				var baseline_requested := requested
				requested = lerpf(
					baseline_requested,
					float(joint_torque_overrides[String(state["joint_id"])]),
					clampf(joint_torque_override_blend_fraction, 0.0, 1.0)
				)
				active_components["br14a.protective_contact_task_space"] = (
					requested - baseline_requested
				)
			if joint_torque_additions.has(String(state["joint_id"])):
				var addition := float(joint_torque_additions[String(state["joint_id"])])
				requested += addition
				active_components["br14a.candidate_internal_task_addition"] = addition
			var plan := (
				JointActuatorScript
				. resolve_and_plan(
					{
						"schema_version": JointActuatorScript.INPUT_SCHEMA_VERSION,
						"tick": tick,
						"joint_id": state["joint_id"],
						"parent_body_id": state["parent_id"],
						"child_body_id": state["child_id"],
						"source_id": "br14a_spatial_controller",
						"behavior_state":
						String(experiment.get("behavior_state", "FREE_3D_STATIC_STANCE")),
						"axis_world": axis_world,
						"pivot_world": parent.to_global(state["anchor_parent_local"]),
						"angular_velocity_rad_s": rate,
						"active_components": active_components,
						"passive_components": {},
						"previous_active_nm": state["previous_active_nm"],
						"previous_activation": state["previous_activation"],
						"step_s": step_s,
					},
					_actuator_spec(profile, "%s.actuator" % String(state["joint_id"]))
				)
			)
			if not bool(plan.get("ok", false)):
				return {
					"ok": false,
					"failure_code": String(plan.get("failure_code", "SPATIAL_STANCE_PLAN_FAILED")),
				}
			plans.append(plan["command"])
			resolutions.append(plan["resolution"])
			state_order.append(state)
	var ledger = CommandLedgerScript.new()
	if not ledger.begin_tick(tick):
		return {"ok": false, "failure_code": "SPATIAL_STANCE_LEDGER_BEGIN_FAILED"}
	for command_value in plans:
		if not ledger.queue_joint(command_value):
			return {"ok": false, "failure_code": "SPATIAL_STANCE_LEDGER_QUEUE_FAILED"}
	var envelope := (
		ledger
		. seal(
			{
				"run_id": String(experiment["experiment_id"]),
				"command_id": tick,
				"source_frame_id": tick,
				"applied_transition": [tick, tick + 1],
				"mode": String(experiment.get("behavior_state", "FREE_3D_STATIC_STANCE")),
			}
		)
	)
	var before_receipts := (receipt_sink.call("values") as Array).size()
	var execution := ActuationExecutorScript.apply_command_envelope(
		envelope, body_by_id, receipt_sink
	)
	if not bool(execution.get("ok", false)):
		return {
			"ok": false,
			"failure_code": String(execution.get("error", "SPATIAL_STANCE_EXECUTION_FAILED")),
		}
	var all_receipts: Array = receipt_sink.call("values")
	var receipts: Array = all_receipts.slice(before_receipts)
	var expected_operations: Array = []
	for command_value in plans:
		expected_operations.append_array(command_value["planned_application_operations"])
	var receipts_complete := _receipts_match(
		receipts, String(envelope["command_payload_sha256"]), expected_operations
	)
	var maximum_pairing := 0.0
	var maximum_applied := 0.0
	var saturation_count := 0
	var active_clamp_count := 0
	var rate_limit_count := 0
	var structural_count := 0
	for index in range(resolutions.size()):
		var resolution: Dictionary = resolutions[index]
		var state: Dictionary = state_order[index]
		state["previous_active_nm"] = float(resolution["applied_active_nm"])
		state["previous_activation"] = float(resolution["activation_next"])
		maximum_applied = maxf(maximum_applied, absf(float(resolution["applied_total_nm"])))
		maximum_pairing = maxf(
			maximum_pairing, float(plans[index]["diagnostics"]["pairing_residual_nm"])
		)
		if (
			bool(resolution["active_saturated"])
			or bool(resolution["torque_rate_limited"])
			or bool(resolution["structural_saturated"])
		):
			saturation_count += 1
		if bool(resolution["active_saturated"]):
			active_clamp_count += 1
		if bool(resolution["torque_rate_limited"]):
			rate_limit_count += 1
		if bool(resolution["structural_saturated"]):
			structural_count += 1
	return {
		"ok": true,
		"receipts_complete": receipts_complete,
		"maximum_pairing_residual_nm": maximum_pairing,
		"maximum_applied_torque_nm": maximum_applied,
		"actuator_saturation_count": saturation_count,
		"active_envelope_clamp_count": active_clamp_count,
		"torque_rate_limit_count": rate_limit_count,
		"structural_saturation_count": structural_count,
		"active_command_count": resolutions.size(),
	}


static func _static_feedforward_nm(
	profile: Dictionary, limb: Dictionary, state: Dictionary
) -> float:
	var axis := _vector3(state["axis_world_initial"])
	var pivot := _vector3(state["pivot_world_initial"])
	var contact := _vector3(limb["configuration"]["contact_point_world_m"])
	var normal_force := (
		float(profile["whole_system_mass_kg"]) * float(profile["gravity_m_s2"]) / 4.0
	)
	var generalized := axis.dot((contact - pivot).cross(Vector3.UP * normal_force))
	var gravity := Vector3.DOWN * float(profile["gravity_m_s2"])
	var upper: RigidBody3D = limb["upper"]
	var lower: RigidBody3D = limb["lower"]
	if String(state["role"]).begins_with("hip_"):
		generalized += axis.dot((upper.global_position - pivot).cross(gravity * upper.mass))
	generalized += axis.dot((lower.global_position - pivot).cross(gravity * lower.mass))
	return generalized


static func _orientation_error_world(
	parent: RigidBody3D, child: RigidBody3D, desired_relative_value: Variant
) -> Vector3:
	var desired_relative: Basis = desired_relative_value
	var current_relative := parent.global_basis.inverse() * child.global_basis
	# Both bases are expressed in the parent frame. Left-multiplying by the
	# desired orientation yields the shortest parent-frame rotation that maps
	# the current child orientation back onto the preregistered rest pose.
	# The former current^-1 * desired order expressed the correction in the
	# moving child frame and cross-coupled the two active hip axes.
	var delta := desired_relative * current_relative.inverse()
	var quaternion := delta.get_rotation_quaternion().normalized()
	if quaternion.w < 0.0:
		quaternion = Quaternion(-quaternion.x, -quaternion.y, -quaternion.z, -quaternion.w)
	var angle := quaternion.get_angle()
	if angle <= 1.0e-9:
		return Vector3.ZERO
	return parent.global_basis * quaternion.get_axis().normalized() * angle


static func _joint_geometry_diagnostics(torso: RigidBody3D, limb_value: Variant) -> Dictionary:
	var limb: Dictionary = limb_value
	var upper: RigidBody3D = limb["upper"]
	var lower: RigidBody3D = limb["lower"]
	var maximum_anchor := 0.0
	var maximum_axis := 0.0
	for state_value in limb["joint_states"]:
		var state: Dictionary = state_value
		var parent := torso if String(state["parent_id"]) == TORSO_ID else upper
		var child := upper if String(state["child_id"]) == String(limb["upper_id"]) else lower
		var anchor_a := parent.to_global(state["anchor_parent_local"])
		var anchor_b := child.to_global(state["anchor_child_local"])
		maximum_anchor = maxf(maximum_anchor, anchor_a.distance_to(anchor_b))
		# A two-axis Generic6DOF hip is intentionally free to rotate the child
		# frame about either active hip axis. Requiring either individual child
		# axis to remain parallel to its parent counterpart would incorrectly
		# reject valid motion about the other active axis. The knee is a true
		# one-axis hinge, so directed-axis agreement is meaningful there.
		if String(state["role"]) == "knee_pitch":
			var axis_a := (parent.global_basis * _vector3(state["axis_parent_local"])).normalized()
			var axis_b := (child.global_basis * _vector3(state["axis_child_local"])).normalized()
			maximum_axis = maxf(maximum_axis, axis_a.angle_to(axis_b))
	return {
		"maximum_anchor_error_m": maximum_anchor,
		"maximum_axis_error_rad": maximum_axis,
	}


static func _actuator_spec(profile: Dictionary, actuator_id: String) -> Dictionary:
	var configuration := {
		"schema_version": ActuatorSpecScript.SCHEMA_VERSION,
		"actuator_id": actuator_id,
	}
	for field in profile["actuator_template"]:
		configuration[field] = profile["actuator_template"][field]
	return ActuatorSpecScript.compile(configuration)["spec"]


static func _body(body_id: String, mass_kg: float, position: Vector3) -> RigidBody3D:
	var body: RigidBody3D = SemanticContactBodyScript.new()
	body.name = body_id
	body.set_meta("lab_body_id", body_id)
	body.mass = mass_kg
	body.position = position
	body.freeze = true
	body.can_sleep = false
	body.continuous_cd = true
	body.collision_layer = LAB_COLLISION_LAYER
	body.collision_mask = LAB_COLLISION_LAYER
	body.contact_monitor = true
	body.max_contacts_reported = 32
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.05
	body.angular_damp = 0.05
	return body


static func _build_floor(friction: float) -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = FLOOR_ID
	floor.set_meta("lab_body_id", FLOOR_ID)
	floor.position = Vector3(0.0, -0.5, 0.0)
	floor.collision_layer = LAB_COLLISION_LAYER
	floor.collision_mask = LAB_COLLISION_LAYER
	_add_box(floor, Vector3(10.0, 1.0, 10.0), Vector3.ZERO, "floor_shape")
	floor.physics_material_override = _material(friction)
	return floor


static func _add_box(
	parent: CollisionObject3D, size: Vector3, local_position: Vector3, shape_id: String
) -> void:
	var collision := CollisionShape3D.new()
	collision.name = shape_id
	collision.set_meta("lab_shape_id", shape_id)
	collision.position = local_position
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	parent.add_child(collision)


static func _material(friction: float) -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.friction = friction
	material.rough = true
	material.bounce = 0.0
	return material


static func _joint_axis(configuration: Dictionary, role: String) -> Vector3:
	for joint_value in configuration["joint_dofs"]:
		if String(joint_value["role"]) == role:
			return _vector3(joint_value["axis_world"]).normalized()
	return Vector3.ZERO


static func _tilt(torso: RigidBody3D) -> float:
	return torso.global_basis.y.normalized().angle_to(Vector3.UP)


static func _receipts_match(receipts: Array, payload_hash: String, operations: Array) -> bool:
	if receipts.size() != operations.size():
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
	var array: Array = value
	return Vector3(float(array[0]), float(array[1]), float(array[2]))
