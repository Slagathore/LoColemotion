class_name LabCanonicalPlanarGetUpRig
extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## BR13 live symmetry-collapsed quadruped prone-to-stance fixture.
##
## One front and one rear rigid strut each represent a mirrored limb pair.
## The root is free in sagittal X/Y translation and pitch. A material
## Generic6DOF guide locks only out-of-plane Z translation, roll, and yaw.
## All commanded joint torque is paired through LabJointActuator, sealed by
## LabCommandLedger, applied by LabActuationExecutor, and receipt-accounted.

const ActuationExecutorScript := preload("res://scripts/lab/actuation_executor.gd")
const CommandLedgerScript := preload("res://scripts/lab/command_ledger.gd")
const EnergyLedgerScript := preload("res://scripts/lab/mechanics/recovery_energy_ledger.gd")
const JointActuatorScript := preload("res://scripts/lab/mechanics/joint_actuator.gd")
const PoseObserverScript := preload(
	"res://scripts/lab/mechanics/quadruped_recovery_pose_observer.gd"
)
const SupervisorScript := preload("res://scripts/lab/mechanics/recovery_phase_supervisor.gd")
const ReceiptSinkScript := preload("res://scripts/lab/records/execution_receipt.gd")

const LAB_COLLISION_LAYER := 1 << 20
const PITCH_AXIS := Vector3.BACK
const ROOT_ID := "br13_canonical_root"
const FRONT_ID := "br13_front_limb_pair"
const REAR_ID := "br13_rear_limb_pair"


func run_trial(
	tree: SceneTree, contract: Dictionary, seed: int, recovery_enabled: bool
) -> Dictionary:
	var configuration: Dictionary = contract["rig_configuration"]
	var actuator_spec: Dictionary = contract["actuator_spec"]
	var viewport := SubViewport.new()
	viewport.name = "BR13_GetUp_%d_%s" % [seed, "active" if recovery_enabled else "control"]
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var world := Node3D.new()
	world.name = "BR13CanonicalGetUpWorld"
	var root_height := float(configuration["initial_root_height_m"])
	var root_position := Vector3(0.0, root_height, 0.0)
	var floor := _build_floor(float(configuration["floor_friction"]))
	var root := _build_root(root_position, configuration)
	var anchor := _build_anchor(root_position)
	var guide := _build_planar_guide(root_position)
	var front := _build_limb_pair("front", -1.0, root_position, configuration)
	var rear := _build_limb_pair("rear", 1.0, root_position, configuration)
	for node in [
		anchor,
		root,
		front["body"],
		rear["body"],
		guide,
		front["hinge"],
		rear["hinge"],
		floor,
	]:
		world.add_child(node)
	viewport.add_child(world)
	guide.node_a = guide.get_path_to(anchor)
	guide.node_b = guide.get_path_to(root)
	for limb in [front, rear]:
		var hinge: HingeJoint3D = limb["hinge"]
		var body: RigidBody3D = limb["body"]
		hinge.node_a = hinge.get_path_to(root)
		hinge.node_b = hinge.get_path_to(body)
	await tree.process_frame
	await tree.physics_frame
	for body in [root, front["body"], rear["body"]]:
		(body as RigidBody3D).freeze = false
		(body as RigidBody3D).sleeping = false
	_reset_pose(root, front, rear, root_position, configuration, seed)
	await tree.physics_frame

	var supervisor = SupervisorScript.new()
	var supervisor_result := supervisor.configure(configuration["supervisor_configuration"])
	if not bool(supervisor_result.get("ok", false)):
		viewport.queue_free()
		await tree.physics_frame
		return supervisor_result
	var pose_configuration: Dictionary = configuration["pose_configuration"]
	var energy_configuration: Dictionary = configuration["energy_configuration"]
	var preflight := EnergyLedgerScript.preflight(
		energy_configuration, configuration["energy_preflight"]
	)
	if not bool(preflight.get("ok", false)):
		viewport.queue_free()
		await tree.physics_frame
		return preflight
	var energy_gate_passed := bool(preflight["report"]["feasible"])
	var bodies := {
		ROOT_ID: root,
		FRONT_ID: front["body"],
		REAR_ID: rear["body"],
	}
	var measured_bodies: Array[RigidBody3D] = [root, front["body"], rear["body"]]
	var receipt_sink = ReceiptSinkScript.new(
		"br13_get_up_%d_%s" % [seed, "active" if recovery_enabled else "control"]
	)
	var step_s := 1.0 / float(configuration["physics_hz"])
	var fixture_complete := true
	var fixture_failure_code := ""
	var all_receipts_complete := true
	var executed_ticks := 0
	var phase_trace: Array[String] = []
	var phase_first_ticks: Dictionary = {}
	var maximum_applied_torque_nm := 0.0
	var maximum_pairing_residual_nm := 0.0
	var actuator_saturation_count := 0
	var recovery_command_count := 0
	var stance_command_count := 0
	var recovery_command_after_handoff_count := 0
	var stance_command_during_dwell_count := 0
	var root_rescue_operation_count := 0
	var foot_pin_operation_count := 0
	var pose_teleport_operation_count := 0
	var automatic_creature_guidance_operation_count := 0
	var positive_actuator_work_j := 0.0
	var absorbed_actuator_work_j := 0.0
	var maximum_out_of_plane_drift_m := absf(root.global_position.z)
	var maximum_roll_rad := 0.0
	var maximum_yaw_rad := 0.0
	var maximum_root_pitch_rad := absf(_root_pitch(root))
	var front_contact_ticks := 0
	var rear_contact_ticks := 0
	var ventral_contact_ticks := 0
	var initial_pose_state := "UNKNOWN"
	var final_pose_state := "UNKNOWN"
	var initial_com_height_m := _system_com(measured_bodies).y
	var initial_kinetic_energy_j := _kinetic_energy(measured_bodies)
	var initial_linear_momentum_z_n_s := _linear_momentum(measured_bodies).z
	var initial_mechanical_energy_j := (
		initial_kinetic_energy_j
		+ _potential_energy(measured_bodies, float(configuration["gravity_m_s2"]))
	)
	var minimum_com_height_m := initial_com_height_m
	var maximum_com_height_m := initial_com_height_m
	var supervisor_phase := "CONFIRM_PRONE"
	for tick in int(configuration["trial_ticks"]):
		var front_bearing := floor in (front["body"] as RigidBody3D).get_colliding_bodies()
		var rear_bearing := floor in (rear["body"] as RigidBody3D).get_colliding_bodies()
		var ventral_contact := floor in root.get_colliding_bodies()
		if front_bearing:
			front_contact_ticks += 1
		if rear_bearing:
			rear_contact_ticks += 1
		if ventral_contact:
			ventral_contact_ticks += 1
		var pose_result := (
			PoseObserverScript
			. observe(
				pose_configuration,
				{
					"schema_version": "quadruped_recovery_pose_observation_v1",
					"tick": tick,
					"torso_height_m": root.global_position.y,
					"reference_stance_height_m": float(configuration["reference_stance_height_m"]),
					"linear_speed_m_s": root.linear_velocity.length(),
					"angular_speed_rad_s": root.angular_velocity.length(),
					"ventral_contact": ventral_contact,
					"front_pair_bearing": front_bearing,
					"rear_pair_bearing": rear_bearing,
					"forbidden_contact_roles": [],
					"sensor_valid": true,
				}
			)
		)
		if not bool(pose_result.get("ok", false)):
			fixture_complete = false
			fixture_failure_code = String(pose_result.get("failure_code", "POSE_OBSERVER_FAILED"))
			break
		var pose: Dictionary = pose_result["observation"]
		if tick == 0:
			initial_pose_state = String(pose["state"])
		final_pose_state = String(pose["state"])
		var current_recovery_active := (
			recovery_enabled and supervisor_phase in ["ESTABLISH_DISTAL_CONTACT", "RAISE_BODY"]
		)
		var current_stance_active := (
			recovery_enabled and supervisor_phase in ["STANCE_HANDOFF", "STANCE_DWELL", "COMPLETE"]
		)
		var supervisor_state: Dictionary = (
			supervisor
			. observe(
				{
					"schema_version": "recovery_phase_observation_v1",
					"tick": tick,
					"pose_state": String(pose["state"]),
					"height_ratio":
					float(pose["height_ratio"]) if pose["height_ratio"] != null else 0.0,
					"front_pair_bearing": front_bearing,
					"rear_pair_bearing": rear_bearing,
					"energy_gate_passed": energy_gate_passed,
					"actuator_reserve_passed": energy_gate_passed,
					"forbidden_contact_observed": false,
					"recovery_controller_active": current_recovery_active,
					"stance_controller_active": current_stance_active,
				}
			)
		)
		if not bool(supervisor_state.get("ok", false)):
			fixture_complete = false
			fixture_failure_code = String(
				supervisor_state.get("failure_code", "RECOVERY_SUPERVISOR_FAILED")
			)
			break
		supervisor_phase = String(supervisor_state["phase"])
		if phase_trace.is_empty() or phase_trace[-1] != supervisor_phase:
			phase_trace.append(supervisor_phase)
			phase_first_ticks[supervisor_phase] = tick
		var behavior_state := "ZERO_COMMAND_CONTROL"
		var command_active := false
		if recovery_enabled and supervisor_phase in ["ESTABLISH_DISTAL_CONTACT", "RAISE_BODY"]:
			behavior_state = "RECOVERY"
			command_active = true
			recovery_command_count += 1
			if phase_first_ticks.has("STANCE_HANDOFF"):
				recovery_command_after_handoff_count += 1
		elif (
			recovery_enabled and supervisor_phase in ["STANCE_HANDOFF", "STANCE_DWELL", "COMPLETE"]
		):
			behavior_state = "STANCE"
			command_active = true
			stance_command_count += 1
			if supervisor_phase in ["STANCE_DWELL", "COMPLETE"]:
				stance_command_during_dwell_count += 1
		var command_result := _apply_joint_commands(
			tick,
			root,
			front,
			rear,
			behavior_state,
			command_active,
			configuration,
			actuator_spec,
			bodies,
			receipt_sink,
			step_s
		)
		if not bool(command_result.get("ok", false)):
			fixture_complete = false
			fixture_failure_code = String(
				command_result.get("failure_code", "RECOVERY_COMMAND_FAILED")
			)
			break
		maximum_applied_torque_nm = maxf(
			maximum_applied_torque_nm, float(command_result["maximum_applied_torque_nm"])
		)
		maximum_pairing_residual_nm = maxf(
			maximum_pairing_residual_nm, float(command_result["maximum_pairing_residual_nm"])
		)
		actuator_saturation_count += int(command_result["actuator_saturation_count"])
		all_receipts_complete = (
			all_receipts_complete and bool(command_result["receipts_complete"])
		)
		await tree.physics_frame
		for body in measured_bodies:
			body.sleeping = false
		var commanded_resolutions: Array = command_result["resolutions"]
		for resolution_index in commanded_resolutions.size():
			var resolution: Dictionary = commanded_resolutions[resolution_index]
			var limb: Dictionary = front if resolution_index == 0 else rear
			var limb_body: RigidBody3D = limb["body"]
			var rate_before := float(resolution["angular_velocity_rad_s"])
			var rate_after := (limb_body.angular_velocity - root.angular_velocity).dot(PITCH_AXIS)
			# The executor applies a constant paired torque for this physics
			# transition. Trapezoidal relative-rate integration captures the
			# work performed while that torque accelerates the joint; using
			# only the pre-step rate materially undercounts fast activation.
			var work := (
				float(resolution["applied_total_nm"]) * 0.5 * (rate_before + rate_after) * step_s
			)
			if work >= 0.0:
				positive_actuator_work_j += work
			else:
				absorbed_actuator_work_j += -work
		executed_ticks = tick + 1
		var com_height := _system_com(measured_bodies).y
		minimum_com_height_m = minf(minimum_com_height_m, com_height)
		maximum_com_height_m = maxf(maximum_com_height_m, com_height)
		maximum_out_of_plane_drift_m = maxf(
			maximum_out_of_plane_drift_m, absf(root.global_position.z)
		)
		var euler := root.global_basis.get_euler()
		maximum_roll_rad = maxf(maximum_roll_rad, absf(euler.x))
		maximum_yaw_rad = maxf(maximum_yaw_rad, absf(euler.y))
		maximum_root_pitch_rad = maxf(maximum_root_pitch_rad, absf(_root_pitch(root)))

	var final_com_height_m := _system_com(measured_bodies).y
	var final_kinetic_energy_j := _kinetic_energy(measured_bodies)
	var final_mechanical_energy_j := (
		final_kinetic_energy_j
		+ _potential_energy(measured_bodies, float(configuration["gravity_m_s2"]))
	)
	var inferred_guide_linear_impulse_z_n_s := (
		_linear_momentum(measured_bodies).z - initial_linear_momentum_z_n_s
	)
	var inferred_guide_work_j := 0.0
	var mechanical_energy_change_j := final_mechanical_energy_j - initial_mechanical_energy_j
	var net_actuator_work_j := positive_actuator_work_j - absorbed_actuator_work_j
	var inferred_contact_dissipation_j := maxf(
		0.0, net_actuator_work_j + inferred_guide_work_j - mechanical_energy_change_j
	)
	var energy_trace := {
		"schema_version": "recovery_energy_trace_v1",
		"initial_com_height_m": initial_com_height_m,
		"final_com_height_m": final_com_height_m,
		"initial_kinetic_energy_j": initial_kinetic_energy_j,
		"final_kinetic_energy_j": final_kinetic_energy_j,
		"actuator_positive_work_j": positive_actuator_work_j,
		"actuator_absorbed_work_j": absorbed_actuator_work_j,
		"known_external_work_j": 0.0,
		"inferred_guide_work_j": inferred_guide_work_j,
		"reported_contact_dissipation_j": inferred_contact_dissipation_j,
	}
	var energy_reconciliation := EnergyLedgerScript.reconcile(energy_configuration, energy_trace)
	var energy_report: Dictionary = {}
	if bool(energy_reconciliation.get("ok", false)):
		energy_report = energy_reconciliation["report"]
	var final_front_bearing := floor in (front["body"] as RigidBody3D).get_colliding_bodies()
	var final_rear_bearing := floor in (rear["body"] as RigidBody3D).get_colliding_bodies()
	var final_ventral_contact := floor in root.get_colliding_bodies()
	var complete_observed := (
		supervisor_phase == "COMPLETE"
		and final_pose_state == "STANCE"
		and final_front_bearing
		and final_rear_bearing
		and not final_ventral_contact
	)
	var final_max_linear_speed_m_s := 0.0
	var final_max_angular_speed_rad_s := 0.0
	for body in measured_bodies:
		final_max_linear_speed_m_s = maxf(final_max_linear_speed_m_s, body.linear_velocity.length())
		final_max_angular_speed_rad_s = maxf(
			final_max_angular_speed_rad_s, body.angular_velocity.length()
		)
	var summary := {
		"schema_version": "canonical_planar_get_up_summary_v1",
		"configuration_sha256": contract["configuration_sha256"],
		"profile_sha256": contract["profile"]["profile_sha256"],
		"actuator_spec_sha256": actuator_spec["spec_sha256"],
		"seed": seed,
		"recovery_enabled": recovery_enabled,
		"fixture_complete": fixture_complete,
		"fixture_failure_code": fixture_failure_code,
		"executed_ticks": executed_ticks,
		"planar_guide_exact": _planar_guide_exact(guide),
		"front_hinge_exact": _hinge_exact(front["hinge"]),
		"rear_hinge_exact": _hinge_exact(rear["hinge"]),
		"initial_pose_state": initial_pose_state,
		"final_pose_state": final_pose_state,
		"final_supervisor_phase": supervisor_phase,
		"phase_trace": phase_trace,
		"phase_first_ticks": phase_first_ticks,
		"complete_observed": complete_observed,
		"initial_com_height_m": initial_com_height_m,
		"final_com_height_m": final_com_height_m,
		"minimum_com_height_m": minimum_com_height_m,
		"maximum_com_height_m": maximum_com_height_m,
		"com_height_gain_m": final_com_height_m - initial_com_height_m,
		"initial_kinetic_energy_j": initial_kinetic_energy_j,
		"final_kinetic_energy_j": final_kinetic_energy_j,
		"initial_mechanical_energy_j": initial_mechanical_energy_j,
		"final_mechanical_energy_j": final_mechanical_energy_j,
		"actuator_positive_work_j": positive_actuator_work_j,
		"actuator_absorbed_work_j": absorbed_actuator_work_j,
		"net_actuator_work_j": net_actuator_work_j,
		"inferred_contact_dissipation_j": inferred_contact_dissipation_j,
		"inferred_guide_linear_impulse_z_n_s": inferred_guide_linear_impulse_z_n_s,
		"inferred_guide_work_j": inferred_guide_work_j,
		"energy_reconciliation_ok": bool(energy_reconciliation.get("ok", false)),
		"energy_reconciliation_accepted": bool(energy_report.get("accepted", false)),
		"energy_balance_residual_j": float(energy_report.get("energy_balance_residual_j", INF)),
		"front_contact_fraction": float(front_contact_ticks) / maxf(float(executed_ticks), 1.0),
		"rear_contact_fraction": float(rear_contact_ticks) / maxf(float(executed_ticks), 1.0),
		"ventral_contact_fraction": float(ventral_contact_ticks) / maxf(float(executed_ticks), 1.0),
		"final_front_pair_bearing": final_front_bearing,
		"final_rear_pair_bearing": final_rear_bearing,
		"final_ventral_contact": final_ventral_contact,
		"final_max_linear_speed_m_s": final_max_linear_speed_m_s,
		"final_max_angular_speed_rad_s": final_max_angular_speed_rad_s,
		"maximum_root_pitch_rad": maximum_root_pitch_rad,
		"maximum_out_of_plane_drift_m": maximum_out_of_plane_drift_m,
		"maximum_roll_rad": maximum_roll_rad,
		"maximum_yaw_rad": maximum_yaw_rad,
		"maximum_applied_torque_nm": maximum_applied_torque_nm,
		"maximum_pairing_residual_nm": maximum_pairing_residual_nm,
		"actuator_saturation_count": actuator_saturation_count,
		"recovery_command_count": recovery_command_count,
		"stance_command_count": stance_command_count,
		"recovery_command_after_handoff_count": recovery_command_after_handoff_count,
		"stance_command_during_dwell_count": stance_command_during_dwell_count,
		"all_receipts_complete": all_receipts_complete,
		"root_rescue_operation_count": root_rescue_operation_count,
		"foot_pin_operation_count": foot_pin_operation_count,
		"pose_teleport_operation_count": pose_teleport_operation_count,
		"automatic_creature_guidance_operation_count": automatic_creature_guidance_operation_count,
		"guide_work_is_residual_inferred": true,
		"contact_dissipation_is_residual_inferred": true,
		"free_3d_recovery_established": false,
		"morphology_transfer_established": false,
		"gait_established": false,
		"walking_established": false,
	}
	viewport.queue_free()
	await tree.physics_frame
	return {"ok": true, "summary": summary}


static func _apply_joint_commands(
	tick: int,
	root: RigidBody3D,
	front: Dictionary,
	rear: Dictionary,
	behavior_state: String,
	command_active: bool,
	configuration: Dictionary,
	actuator_spec: Dictionary,
	bodies: Dictionary,
	receipt_sink: RefCounted,
	step_s: float
) -> Dictionary:
	var plans: Array = []
	var resolutions: Array = []
	for limb in [front, rear]:
		var body: RigidBody3D = limb["body"]
		var angle := _absolute_limb_angle(body)
		var rate := (body.angular_velocity - root.angular_velocity).dot(PITCH_AXIS)
		var requested := 0.0
		if command_active:
			requested = (
				-float(configuration["joint_position_gain_nm_rad"]) * angle
				- float(configuration["joint_velocity_gain_nm_s_rad"]) * rate
			)
		var plan := (
			JointActuatorScript
			. resolve_and_plan(
				{
					"schema_version": "joint_actuator_input_v1",
					"tick": tick,
					"joint_id": "br13_%s_pair_hip" % String(limb["label"]),
					"parent_body_id": ROOT_ID,
					"child_body_id": String(limb["body_id"]),
					"source_id":
					(
						"br13.recovery_controller"
						if behavior_state == "RECOVERY"
						else (
							"br13.stance_controller"
							if behavior_state == "STANCE"
							else "br13.zero_command_control"
						)
					),
					"behavior_state": behavior_state,
					"axis_world": PITCH_AXIS,
					"pivot_world": _hip_position(root, float(limb["side"]), configuration),
					"angular_velocity_rad_s": rate,
					"active_components":
					{
						"br13.joint_space_position_nm":
						(
							-float(configuration["joint_position_gain_nm_rad"]) * angle
							if command_active
							else 0.0
						),
						"br13.joint_space_damping_nm":
						(
							-float(configuration["joint_velocity_gain_nm_s_rad"]) * rate
							if command_active
							else 0.0
						),
					},
					"passive_components": {},
					"previous_active_nm": float(limb["previous_active_nm"]),
					"previous_activation": float(limb["previous_activation"]),
					"step_s": step_s,
				},
				actuator_spec
			)
		)
		if not bool(plan.get("ok", false)):
			return {
				"ok": false,
				"failure_code": String(plan.get("failure_code", "JOINT_PLAN_FAILED")),
			}
		plans.append(plan["command"])
		resolutions.append(plan["resolution"])
	var ledger = CommandLedgerScript.new()
	if not ledger.begin_tick(tick):
		return {"ok": false, "failure_code": "RECOVERY_LEDGER_BEGIN_FAILED"}
	for command_value in plans:
		if not ledger.queue_joint(command_value):
			return {"ok": false, "failure_code": "RECOVERY_LEDGER_QUEUE_FAILED"}
	var envelope := (
		ledger
		. seal(
			{
				"run_id": "br13_canonical_get_up",
				"command_id": tick,
				"source_frame_id": tick,
				"applied_transition": [tick, tick + 1],
				"mode": "BR13_CANONICAL_PLANAR_GET_UP",
			}
		)
	)
	var existing_receipts: Array = receipt_sink.call("values")
	var before_receipts: int = existing_receipts.size()
	var execution := ActuationExecutorScript.apply_command_envelope(envelope, bodies, receipt_sink)
	if not bool(execution.get("ok", false)):
		return {
			"ok": false,
			"failure_code": String(execution.get("error", "RECOVERY_EXECUTION_FAILED")),
		}
	var all_receipts: Array = receipt_sink.call("values")
	var receipts: Array = all_receipts.slice(before_receipts)
	var expected_operations: Array = []
	for command_value in plans:
		var command: Dictionary = command_value
		expected_operations.append_array(command["planned_application_operations"])
	var receipts_complete := _receipts_match(
		receipts, String(envelope["command_payload_sha256"]), expected_operations
	)
	var maximum_applied := 0.0
	var maximum_pairing := 0.0
	var saturation_count := 0
	for index in resolutions.size():
		var resolution: Dictionary = resolutions[index]
		var limb: Dictionary = front if index == 0 else rear
		limb["previous_active_nm"] = float(resolution["applied_active_nm"])
		limb["previous_activation"] = float(resolution["activation_next"])
		maximum_applied = maxf(maximum_applied, absf(float(resolution["applied_total_nm"])))
		var command: Dictionary = plans[index]
		maximum_pairing = maxf(
			maximum_pairing, float(command["diagnostics"]["pairing_residual_nm"])
		)
		if (
			bool(resolution["active_saturated"])
			or bool(resolution["torque_rate_limited"])
			or bool(resolution["structural_saturated"])
		):
			saturation_count += 1
	return {
		"ok": true,
		"resolutions": resolutions,
		"receipts_complete": receipts_complete,
		"maximum_applied_torque_nm": maximum_applied,
		"maximum_pairing_residual_nm": maximum_pairing,
		"actuator_saturation_count": saturation_count,
	}


static func _build_root(position: Vector3, configuration: Dictionary) -> RigidBody3D:
	var body := _body(ROOT_ID, float(configuration["root_mass_kg"]), position)
	body.collision_layer = LAB_COLLISION_LAYER
	body.collision_mask = LAB_COLLISION_LAYER
	body.contact_monitor = true
	body.max_contacts_reported = 16
	_add_box(body, _vector3(configuration["root_size_m"]), Vector3.ZERO)
	body.physics_material_override = _material(float(configuration["floor_friction"]))
	return body


static func _build_limb_pair(
	label: String, side: float, root_position: Vector3, configuration: Dictionary
) -> Dictionary:
	var hip := root_position + Vector3(side * float(configuration["hip_half_span_m"]), 0.0, 0.0)
	var length := float(configuration["limb_length_m"])
	var angle_magnitude := float(configuration["initial_splay_angle_rad"])
	var angle := side * angle_magnitude
	var direction := Vector3(sin(angle), -cos(angle), 0.0)
	var body_id := FRONT_ID if label == "front" else REAR_ID
	var body := _body(
		body_id, float(configuration["limb_pair_mass_kg"]), hip + 0.5 * length * direction
	)
	body.rotation = Vector3(0.0, 0.0, angle - PI * 0.5)
	body.collision_layer = LAB_COLLISION_LAYER
	body.collision_mask = LAB_COLLISION_LAYER
	body.contact_monitor = true
	body.max_contacts_reported = 16
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector3.ZERO
	var foot_radius := float(configuration["foot_radius_m"])
	_add_box(
		body,
		Vector3(
			length - 2.0 * foot_radius,
			float(configuration["limb_width_m"]),
			float(configuration["limb_depth_m"])
		),
		Vector3.ZERO
	)
	var foot := CollisionShape3D.new()
	foot.name = "%s_pair_distal" % label
	foot.position = Vector3(length * 0.5, 0.0, 0.0)
	var sphere := SphereShape3D.new()
	sphere.radius = foot_radius
	foot.shape = sphere
	body.add_child(foot)
	body.physics_material_override = _material(float(configuration["floor_friction"]))
	return {
		"label": label,
		"side": side,
		"body_id": body_id,
		"body": body,
		"hinge": _build_hinge("br13_%s_pair_hip" % label, hip),
		"previous_active_nm": 0.0,
		"previous_activation": 0.0,
	}


static func _build_floor(friction: float) -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "br13_floor"
	floor.position = Vector3(0.0, -0.5, 0.0)
	floor.collision_layer = LAB_COLLISION_LAYER
	floor.collision_mask = LAB_COLLISION_LAYER
	_add_box(floor, Vector3(10.0, 1.0, 10.0), Vector3.ZERO)
	floor.physics_material_override = _material(friction)
	return floor


static func _build_anchor(position: Vector3) -> StaticBody3D:
	var anchor := StaticBody3D.new()
	anchor.name = "br13_planar_anchor"
	anchor.position = position
	anchor.collision_layer = 0
	anchor.collision_mask = 0
	return anchor


static func _build_planar_guide(position: Vector3) -> Generic6DOFJoint3D:
	var guide := Generic6DOFJoint3D.new()
	guide.name = "br13_planar_guide"
	guide.position = position
	for axis in ["x", "y", "z"]:
		guide.set("linear_limit_%s/enabled" % axis, axis == "z")
		guide.set("linear_limit_%s/lower_distance" % axis, 0.0)
		guide.set("linear_limit_%s/upper_distance" % axis, 0.0)
		guide.set("linear_motor_%s/enabled" % axis, false)
		guide.set("linear_spring_%s/enabled" % axis, false)
		guide.set("angular_limit_%s/enabled" % axis, axis != "z")
		guide.set("angular_limit_%s/lower_angle" % axis, 0.0)
		guide.set("angular_limit_%s/upper_angle" % axis, 0.0)
		guide.set("angular_motor_%s/enabled" % axis, false)
		guide.set("angular_spring_%s/enabled" % axis, false)
	return guide


static func _build_hinge(name_value: String, position: Vector3) -> HingeJoint3D:
	var hinge := HingeJoint3D.new()
	hinge.name = name_value
	hinge.position = position
	hinge.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
	hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, false)
	return hinge


static func _reset_pose(
	root: RigidBody3D,
	front: Dictionary,
	rear: Dictionary,
	root_position: Vector3,
	configuration: Dictionary,
	seed: int
) -> void:
	root.global_position = root_position
	root.quaternion = Quaternion.IDENTITY
	var seed_velocity := float((seed % 3) - 1) * float(configuration["seed_initial_velocity_m_s"])
	root.linear_velocity = Vector3(seed_velocity, 0.0, 0.0)
	root.angular_velocity = Vector3.ZERO
	var length := float(configuration["limb_length_m"])
	for limb in [front, rear]:
		var side := float(limb["side"])
		var angle := side * float(configuration["initial_splay_angle_rad"])
		var direction := Vector3(sin(angle), -cos(angle), 0.0)
		var hip := _hip_position(root, side, configuration)
		var body: RigidBody3D = limb["body"]
		body.global_position = hip + 0.5 * length * direction
		body.rotation = Vector3(0.0, 0.0, angle - PI * 0.5)
		body.linear_velocity = Vector3(seed_velocity, 0.0, 0.0)
		body.angular_velocity = Vector3.ZERO
		body.sleeping = false
		limb["previous_active_nm"] = 0.0
		limb["previous_activation"] = 0.0
	root.sleeping = false


static func _hip_position(root: RigidBody3D, side: float, configuration: Dictionary) -> Vector3:
	return (
		root.global_position
		+ root.global_basis * Vector3(side * float(configuration["hip_half_span_m"]), 0.0, 0.0)
	)


static func _body(body_id: String, mass_kg: float, position: Vector3) -> RigidBody3D:
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


static func _material(friction: float) -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.friction = friction
	material.rough = true
	material.bounce = 0.0
	return material


static func _add_box(parent: CollisionObject3D, size: Vector3, local_position: Vector3) -> void:
	var collision := CollisionShape3D.new()
	collision.position = local_position
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	parent.add_child(collision)


static func _absolute_limb_angle(body: RigidBody3D) -> float:
	var direction := body.global_basis.x.normalized()
	return atan2(direction.x, -direction.y)


static func _root_pitch(root: RigidBody3D) -> float:
	var direction := root.global_basis.x.normalized()
	return atan2(direction.y, direction.x)


static func _system_com(bodies: Array[RigidBody3D]) -> Vector3:
	var mass := 0.0
	var weighted := Vector3.ZERO
	for body in bodies:
		mass += body.mass
		weighted += body.mass * body.global_position
	return weighted / mass


static func _linear_momentum(bodies: Array[RigidBody3D]) -> Vector3:
	var result := Vector3.ZERO
	for body in bodies:
		result += body.mass * body.linear_velocity
	return result


static func _potential_energy(bodies: Array[RigidBody3D], gravity: float) -> float:
	var result := 0.0
	for body in bodies:
		result += body.mass * gravity * body.global_position.y
	return result


static func _kinetic_energy(bodies: Array[RigidBody3D]) -> float:
	var result := 0.0
	for body in bodies:
		result += 0.5 * body.mass * body.linear_velocity.length_squared()
		var omega_local := body.global_basis.inverse() * body.angular_velocity
		var inertia := body.inertia
		result += (
			0.5
			* (
				inertia.x * omega_local.x * omega_local.x
				+ inertia.y * omega_local.y * omega_local.y
				+ inertia.z * omega_local.z * omega_local.z
			)
		)
	return result


static func _planar_guide_exact(guide: Generic6DOFJoint3D) -> bool:
	if (
		bool(guide.get("linear_limit_x/enabled"))
		or bool(guide.get("linear_limit_y/enabled"))
		or not bool(guide.get("linear_limit_z/enabled"))
		or not bool(guide.get("angular_limit_x/enabled"))
		or not bool(guide.get("angular_limit_y/enabled"))
		or bool(guide.get("angular_limit_z/enabled"))
	):
		return false
	for axis in ["x", "y", "z"]:
		if (
			bool(guide.get("linear_motor_%s/enabled" % axis))
			or bool(guide.get("linear_spring_%s/enabled" % axis))
			or bool(guide.get("angular_motor_%s/enabled" % axis))
			or bool(guide.get("angular_spring_%s/enabled" % axis))
		):
			return false
	return true


static func _hinge_exact(hinge: HingeJoint3D) -> bool:
	return (
		not hinge.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR)
		and not hinge.get_flag(HingeJoint3D.FLAG_USE_LIMIT)
	)


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
	var raw: Array = value
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
