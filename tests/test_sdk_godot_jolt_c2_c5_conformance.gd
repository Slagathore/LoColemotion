extends SceneTree

## Dedicated Godot 4.7 / Jolt C2-C5 conformance fixtures.
##
## This campaign is intentionally separate from locomotion. C2 uses the
## canonical quadruped topology without commanding it. C3 contains no motor
## actuation. C4 uses isolated one-axis motor rigs. C5 validates the declared
## single-semantic-shape contact capability and preserves unavailable load as
## unavailable.

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")

const PHYSICS_HZ := 120
const SOLVER_POLICY := {
	"solver_policy_id": "jolt_120hz_20v_7p_v1",
	"physics_engine": "Jolt Physics",
	"physics_hz": PHYSICS_HZ,
	"solver_velocity_steps": 20,
	"solver_position_steps": 7,
}
const DESCRIPTOR := {
	"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
	"morphology_id": "godot_jolt_c2_c5_reference",
	"torso_length_scale": 1.0,
	"torso_width_scale": 1.0,
	"upper_length_fraction": 18.0 / 35.0,
	"hip_span_scale": 1.0,
	"foot_radius_scale": 1.0,
	"front_limb_mass_scale": 1.0,
}
const LIMB_IDS := ["front_left", "front_right", "rear_left", "rear_right"]
const JOINT_IDS := [
	"front_left_hip",
	"front_left_knee",
	"front_right_hip",
	"front_right_knee",
	"rear_left_hip",
	"rear_left_knee",
	"rear_right_hip",
	"rear_right_knee",
]
const CONTACT_IDS := [
	"front_left_foot",
	"front_right_foot",
	"rear_left_foot",
	"rear_right_foot",
]

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK Godot/Jolt dedicated C2-C5 conformance ===")
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)

	var adapter_receipt := await _run_c2_c5_adapter_fixture()
	_check(bool(adapter_receipt.get("ok", false)), "the C2/C5 adapter fixture completes")
	if bool(adapter_receipt.get("ok", false)):
		_check(
			bool(adapter_receipt.get("c2_topology_complete", false)),
			"C2 topology, semantic ordering, bodies, joints, and contact sites are complete",
		)
		_check(
			bool(adapter_receipt.get("c2_frames_and_limits_bounded", false)),
			"C2 joint frames, axes, limits, nominal anchors, and observations round-trip",
		)
		_check(
			bool(adapter_receipt.get("c2_coordinate_conversion_bounded", false)),
			"C2 canonical base orientation and gravity mapping are bounded",
		)
		_check(
			bool(adapter_receipt.get("c5_declared_capabilities_exact", false)),
			"C5 contact capabilities and unsupported semantics are explicit",
		)
		_check(
			bool(adapter_receipt.get("c5_live_contact_complete", false)),
			"C5 live contacts retain point, normal, velocity, impulse, and shape provenance",
		)
		_check(
			bool(adapter_receipt.get("c5_unavailable_load_preserved", false)),
			"C5 unavailable normal load remains null rather than an invented zero",
		)
		_check(
			bool(adapter_receipt.get("c5_contact_ids_persistent", false)),
			"C5 per-step engine contact identities persist across a stable contact step",
		)

	var passive_receipt := await _run_c3_passive_fixtures()
	_check(bool(passive_receipt.get("ok", false)), "the C3 passive fixture world completes")
	if bool(passive_receipt.get("ok", false)):
		_check(
			bool(passive_receipt.get("mass_inertia_round_trip", false)),
			"C3 mass and custom inertia round-trip exactly",
		)
		_check(
			bool(passive_receipt.get("free_fall_bounded", false)),
			"C3 controller-free free fall matches the analytic envelope",
		)
		_check(
			bool(passive_receipt.get("unconstrained_integration_bounded", false)),
			"C3 gravity-free unconstrained integration matches its envelope",
		)
		_check(
			bool(passive_receipt.get("damping_response_bounded", false)),
			"C3 declared linear and angular damping dissipate without reversal",
		)
		_check(
			bool(passive_receipt.get("pendulum_response_bounded", false)),
			"C3 motor-free hinge pendulum matches period and anchor envelopes",
		)

	var actuator_receipt := await _run_c4_actuator_fixtures()
	_check(bool(actuator_receipt.get("ok", false)), "the C4 actuator fixture world completes")
	if bool(actuator_receipt.get("ok", false)):
		_check(
			bool(actuator_receipt.get("parameters_round_trip", false)),
			"C4 target velocity and impulse-cap parameters round-trip",
		)
		_check(
			bool(actuator_receipt.get("pd_conversion_bounded", false)),
			"C4 position request converts to a bounded host velocity target",
		)
		_check(
			bool(actuator_receipt.get("impulse_response_ordered", false)),
			"C4 higher impulse authority produces the stronger early response",
		)
		_check(
			bool(actuator_receipt.get("physical_response_bounded", false)),
			"C4 the actuated hinge moves toward target without exceeding its speed envelope",
		)
		_check(
			bool(adapter_receipt.get("c4_declared_capabilities_exact", false)),
			"C4 native, approximated, core-only, and unavailable actuator semantics are explicit",
		)

	var receipt := {
		"schema_version": "sporespore_godot_jolt_c2_c5_receipt_v1",
		"ok": _failed == 0,
		"physics_engine": String(ProjectSettings.get_setting("physics/3d/physics_engine", "")),
		"physics_hz": PHYSICS_HZ,
		"solver_velocity_steps":
		int(
			ProjectSettings.get_setting(
				"physics/jolt_physics_3d/simulation/velocity_steps",
				-1,
			)
		),
		"solver_position_steps":
		int(
			ProjectSettings.get_setting(
				"physics/jolt_physics_3d/simulation/position_steps",
				-1,
			)
		),
		"c2_c5_adapter": adapter_receipt,
		"c3_passive": passive_receipt,
		"c4_actuator": actuator_receipt,
		"formal_milestone_acceptance_authorized": false,
		"encyclopedia_admission_authorized": false,
	}
	print("SDK_GODOT_JOLT_C2_C5_RECEIPT ", JSON.stringify(receipt))
	Engine.physics_ticks_per_second = original_hz
	_finish()


func _run_c2_c5_adapter_fixture() -> Dictionary:
	var fixture_compile := FixtureSpecScript.compile(FixtureSpecScript.reference_spec())
	if not bool(fixture_compile.get("ok", false)):
		return _failure("C2_FIXTURE_SPEC_COMPILE_FAILED")
	var fixture: Dictionary = await WaveGaitScript._build_fixture(
		self,
		10.0,
		1.0,
		1.0,
		false,
		{},
		fixture_compile["fixture_spec"],
	)
	if not bool(fixture.get("ok", false)):
		return _failure("C2_FIXTURE_BUILD_FAILED")
	var cleanup_node: Node = fixture["cleanup_node"]
	var torso: RigidBody3D = fixture["torso"]
	var floor: StaticBody3D = fixture["floor"]
	var limbs: Array = fixture["limbs"]
	for _settle_tick in 60:
		await physics_frame
		if WaveGaitScript._all_feet_bear_floor(limbs, floor):
			break

	var adapter := AdapterScript.new()
	var gait_steps := {}
	for limb_id_value in LIMB_IDS:
		gait_steps[String(limb_id_value)] = 0
	var start_result: Dictionary = adapter.start(
		DESCRIPTOR,
		gait_steps,
		0.0,
		torso.global_position,
		Vector3.BACK,
		0.0,
		PHYSICS_HZ,
		SOLVER_POLICY,
		2.0e-8,
		"clocked",
		false,
	)
	if not bool(start_result.get("ok", false)):
		cleanup_node.queue_free()
		await physics_frame
		return _failure("C2_ADAPTER_START_FAILED")
	var morphology_result: Dictionary = adapter.compiled_morphology_for_conformance()
	var first_sample: Dictionary = adapter.sample(
		0,
		0.0,
		"clocked",
		torso,
		limbs,
		floor,
	)
	if (
		not bool(morphology_result.get("ok", false))
		or not bool(first_sample.get("ok", false))
	):
		cleanup_node.queue_free()
		await physics_frame
		return _failure("C2_ADAPTER_SAMPLE_FAILED")
	var morphology: Dictionary = morphology_result["morphology"]
	var manifest: Dictionary = morphology_result["adapter_manifest"]
	var state: Dictionary = (first_sample["request"] as Dictionary)["state"]

	var host_joint_by_sdk_id := {}
	var host_body_by_sdk_id := {"torso": torso}
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var limb_id := String(limb["limb_id"])
		host_body_by_sdk_id["%s_upper" % limb_id] = limb["upper"]
		host_body_by_sdk_id["%s_distal" % limb_id] = limb["foot"]
		for joint_state_value in limb["joint_states"]:
			var joint_state: Dictionary = joint_state_value
			var suffix := "hip" if String(joint_state["role"]) == "hip_pitch" else "knee"
			host_joint_by_sdk_id["%s_%s" % [limb_id, suffix]] = joint_state

	var topology_complete := (
		(morphology.get("ordered_limb_ids", []) as Array) == LIMB_IDS
		and (morphology.get("ordered_joint_ids", []) as Array) == JOINT_IDS
		and (morphology.get("ordered_contact_site_ids", []) as Array) == CONTACT_IDS
		and host_body_by_sdk_id.size() == 9
		and host_joint_by_sdk_id.size() == 8
		and (state.get("ordered_joint_observations", []) as Array).size() == 8
		and (state.get("ordered_contact_observations", []) as Array).size() == 4
	)
	var maximum_anchor_error_m := 0.0
	var maximum_axis_error_rad := 0.0
	var maximum_limit_error_rad := 0.0
	var maximum_mass_error_kg := 0.0
	var observations_finite := true
	for body_value in morphology.get("bodies", []):
		var body_spec: Dictionary = body_value
		var body_id := String(body_spec["body_id"])
		if not host_body_by_sdk_id.has(body_id):
			topology_complete = false
			continue
		var host_body: RigidBody3D = host_body_by_sdk_id[body_id]
		maximum_mass_error_kg = maxf(
			maximum_mass_error_kg,
			absf(host_body.mass - float(body_spec["mass_kg"])),
		)
	for joint_value in morphology.get("joints", []):
		var joint_spec: Dictionary = joint_value
		var joint_id := String(joint_spec["joint_id"])
		if not host_joint_by_sdk_id.has(joint_id):
			topology_complete = false
			continue
		var joint_state: Dictionary = host_joint_by_sdk_id[joint_id]
		var host_joint: HingeJoint3D = joint_state["joint"]
		var geometry: Dictionary = WaveGaitScript._joint_geometry_receipt(joint_state)
		maximum_anchor_error_m = maxf(
			maximum_anchor_error_m,
			float(geometry["anchor_error_m"]),
		)
		maximum_axis_error_rad = maxf(
			maximum_axis_error_rad,
			float(geometry["hinge_axis_error_rad"]),
		)
		maximum_limit_error_rad = maxf(
			maximum_limit_error_rad,
			maxf(
				absf(
					host_joint.get_param(HingeJoint3D.PARAM_LIMIT_LOWER)
					- float(joint_spec["lower_limit_rad"])
				),
				absf(
					host_joint.get_param(HingeJoint3D.PARAM_LIMIT_UPPER)
					- float(joint_spec["upper_limit_rad"])
				),
			),
		)
	for observation_value in state["ordered_joint_observations"]:
		var observation: Dictionary = observation_value
		observations_finite = (
			observations_finite
			and is_finite(float(observation["position_rad"]))
			and is_finite(float(observation["velocity_rad_s"]))
			and is_finite(float(observation["anchor_error_m"]))
		)
	var orientation: Dictionary = (state["base_pose_world"] as Dictionary)["orientation_xyzw"]
	var orientation_norm := sqrt(
		float(orientation["x"]) * float(orientation["x"])
		+ float(orientation["y"]) * float(orientation["y"])
		+ float(orientation["z"]) * float(orientation["z"])
		+ float(orientation["w"]) * float(orientation["w"])
	)
	var gravity: Dictionary = state["gravity_world_m_s2"]
	var expected_gravity_m_s2 := float(
		ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	)
	var coordinate_conversion_bounded := (
		absf(orientation_norm - 1.0) <= 5.0e-8
		and absf(float(gravity["x"])) <= 1.0e-12
		and absf(float(gravity["y"]) + expected_gravity_m_s2) <= 5.0e-7
		and absf(float(gravity["z"])) <= 1.0e-12
	)

	var contact_capabilities: Dictionary = manifest.get("contact_capabilities", {})
	var actuator_capabilities: Dictionary = manifest.get("actuator_capabilities", {})
	var declared_contacts_exact := (
		String(contact_capabilities.get("point", "")) == "host_observer_only"
		and String(contact_capabilities.get("normal", "")) == "host_observer_only"
		and String(contact_capabilities.get("relative_velocity", "")) == "host_observer_only"
		and String(contact_capabilities.get("raw_impulse", "")) == "host_observer_only"
		and String(contact_capabilities.get("normal_load", "")) == "unavailable"
		and not bool(contact_capabilities.get("multi_shape_contact_sites_supported", true))
	)
	var declared_actuators_exact := (
		String(actuator_capabilities.get("position_target", ""))
		== "adapter_pd_to_velocity"
		and String(actuator_capabilities.get("velocity_target", "")) == "native_hinge_motor"
		and String(actuator_capabilities.get("effort_target", "")) == "unavailable"
		and String(actuator_capabilities.get("impulse_limit", "")) == "native_per_step_cap"
		and String(actuator_capabilities.get("rate_limit", "")) == "core_only"
	)
	var first_ids_by_contact := {}
	var live_contact_complete := true
	var unavailable_load_preserved := true
	for contact_value in state["ordered_contact_observations"]:
		var contact: Dictionary = contact_value
		var contact_id := String(contact["contact_site_id"])
		var provenance: Dictionary = contact["provenance"]
		var engine_ids: Array = provenance["engine_contact_ids"]
		first_ids_by_contact[contact_id] = engine_ids.duplicate()
		live_contact_complete = (
			live_contact_complete
			and bool(contact["presence"])
			and bool(contact["bears_support"])
			and not engine_ids.is_empty()
			and String(provenance["quality"]) == "qualified_bearing"
		)
		unavailable_load_preserved = unavailable_load_preserved and contact["normal_load_n"] == null
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var foot: RigidBody3D = limb["foot"]
		var samples: Variant = foot.get("latest_semantic_contact_samples")
		if typeof(samples) != TYPE_ARRAY or (samples as Array).is_empty():
			live_contact_complete = false
			continue
		for sample_value in samples:
			var sample: Dictionary = sample_value
			var normal: Vector3 = sample["local_normal_world_unit"]
			var impulse: Vector3 = sample["raw_impulse_world_nms"]
			live_contact_complete = (
				live_contact_complete
				and (sample["local_position_world_m"] as Vector3).is_finite()
				and (sample["collider_position_world_m"] as Vector3).is_finite()
				and normal.is_finite()
				and absf(normal.length() - 1.0) <= 1.0e-4
				and (sample["relative_velocity_world_m_s"] as Vector3).is_finite()
				and impulse.is_finite()
				and int(sample["local_shape_index"]) >= 0
				and int(sample["collider_shape_index"]) >= 0
			)
	await physics_frame
	var second_sample: Dictionary = adapter.sample(
		1,
		0.0,
		"clocked",
		torso,
		limbs,
		floor,
	)
	var contact_ids_persistent := bool(second_sample.get("ok", false))
	if contact_ids_persistent:
		var second_state: Dictionary = (second_sample["request"] as Dictionary)["state"]
		for contact_value in second_state["ordered_contact_observations"]:
			var contact: Dictionary = contact_value
			var contact_id := String(contact["contact_site_id"])
			var second_ids: Array = (contact["provenance"] as Dictionary)["engine_contact_ids"]
			contact_ids_persistent = (
				contact_ids_persistent
				and first_ids_by_contact.has(contact_id)
				and not second_ids.is_empty()
				and second_ids == (first_ids_by_contact[contact_id] as Array)
			)
	var result := {
		"ok": true,
		"failure_code": "",
		"c2_topology_complete": topology_complete,
		"c2_frames_and_limits_bounded":
		(
			observations_finite
			and maximum_anchor_error_m <= 2.5e-2
			and maximum_axis_error_rad <= 1.2e-1
			and maximum_limit_error_rad <= 1.0e-9
			and maximum_mass_error_kg <= 1.0e-9
		),
		"c2_coordinate_conversion_bounded": coordinate_conversion_bounded,
		"c4_declared_capabilities_exact": declared_actuators_exact,
		"c5_declared_capabilities_exact": declared_contacts_exact,
		"c5_live_contact_complete": live_contact_complete,
		"c5_unavailable_load_preserved": unavailable_load_preserved,
		"c5_contact_ids_persistent": contact_ids_persistent,
		"maximum_anchor_error_m": maximum_anchor_error_m,
		"maximum_axis_error_rad": maximum_axis_error_rad,
		"maximum_limit_error_rad": maximum_limit_error_rad,
		"maximum_mass_error_kg": maximum_mass_error_kg,
		"canonical_orientation_norm": orientation_norm,
		"gravity_y_m_s2": float(gravity["y"]),
		"expected_gravity_m_s2": expected_gravity_m_s2,
		"world_build_count": 1,
		"physical_acceptance_authority": false,
	}
	cleanup_node.queue_free()
	await physics_frame
	return result


func _run_c3_passive_fixtures() -> Dictionary:
	var viewport := _new_viewport("SdkC3PassiveViewport")
	var world := Node3D.new()
	world.name = "SdkC3PassiveWorld"
	viewport.add_child(world)

	var free_fall := _passive_body(
		"FreeFall",
		2.0,
		Vector3(0.3, 0.4, 0.5),
		Vector3(0.10, 0.20, 0.30),
		1.0,
		0.0,
		0.0,
	)
	free_fall.position = Vector3(0.0, 3.0, 0.0)
	var integrator := _passive_body(
		"Integrator",
		1.25,
		Vector3(0.2, 0.2, 0.2),
		Vector3.ZERO,
		0.0,
		0.0,
		0.0,
	)
	integrator.position = Vector3(-3.0, 0.0, 0.0)
	var damped := _passive_body(
		"Damped",
		1.0,
		Vector3(0.2, 0.2, 0.2),
		Vector3.ZERO,
		0.0,
		0.6,
		0.8,
	)
	damped.position = Vector3(-6.0, 0.0, 0.0)
	world.add_child(free_fall)
	world.add_child(integrator)
	world.add_child(damped)

	var pivot := Vector3(4.0, 2.0, 0.0)
	var pendulum_parent := StaticBody3D.new()
	pendulum_parent.name = "PendulumParent"
	pendulum_parent.position = pivot
	pendulum_parent.collision_layer = 0
	pendulum_parent.collision_mask = 0
	world.add_child(pendulum_parent)
	var pendulum := _passive_body(
		"Pendulum",
		1.5,
		Vector3(0.08, 1.0, 0.08),
		Vector3.ZERO,
		1.0,
		0.0,
		0.0,
	)
	var initial_angle := 0.2
	var pivot_to_com := 0.5
	pendulum.quaternion = Quaternion(Vector3.BACK, initial_angle)
	pendulum.position = pivot + Vector3(
		pivot_to_com * sin(initial_angle),
		-pivot_to_com * cos(initial_angle),
		0.0,
	)
	world.add_child(pendulum)
	var pendulum_joint := HingeJoint3D.new()
	pendulum_joint.name = "PassivePendulumHinge"
	pendulum_joint.position = pivot
	pendulum_joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, false)
	pendulum_joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
	world.add_child(pendulum_joint)
	pendulum_joint.node_a = pendulum_joint.get_path_to(pendulum_parent)
	pendulum_joint.node_b = pendulum_joint.get_path_to(pendulum)

	await process_frame
	await physics_frame
	for body in [free_fall, integrator, damped, pendulum]:
		body.freeze = false
		body.sleeping = false
	free_fall.position = Vector3(0.0, 3.0, 0.0)
	free_fall.linear_velocity = Vector3.ZERO
	integrator.position = Vector3(-3.0, 0.0, 0.0)
	integrator.linear_velocity = Vector3(1.25, 0.0, 0.0)
	damped.position = Vector3(-6.0, 0.0, 0.0)
	damped.linear_velocity = Vector3(1.0, 0.0, 0.0)
	damped.angular_velocity = Vector3(0.0, 0.0, 2.0)
	pendulum.quaternion = Quaternion(Vector3.BACK, initial_angle)
	pendulum.position = pivot + Vector3(
		pivot_to_com * sin(initial_angle),
		-pivot_to_com * cos(initial_angle),
		0.0,
	)
	pendulum.linear_velocity = Vector3.ZERO
	pendulum.angular_velocity = Vector3.ZERO

	var free_fall_y_60 := NAN
	var free_fall_vy_60 := NAN
	var integration_x_120 := NAN
	var integration_vx_120 := NAN
	var damped_vx_120 := NAN
	var damped_wz_120 := NAN
	var maximum_pendulum_radius_error_m := 0.0
	var zero_crossing_ticks: Array[int] = []
	var previous_angle := initial_angle
	for tick in 300:
		await physics_frame
		var relative := pendulum.global_position - pivot
		var angle := atan2(relative.x, -relative.y)
		maximum_pendulum_radius_error_m = maxf(
			maximum_pendulum_radius_error_m,
			absf(relative.length() - pivot_to_com),
		)
		if previous_angle * angle < 0.0:
			zero_crossing_ticks.append(tick + 1)
		previous_angle = angle
		if tick + 1 == 60:
			free_fall_y_60 = free_fall.position.y
			free_fall_vy_60 = free_fall.linear_velocity.y
		if tick + 1 == 120:
			integration_x_120 = integrator.position.x
			integration_vx_120 = integrator.linear_velocity.x
			damped_vx_120 = damped.linear_velocity.x
			damped_wz_120 = damped.angular_velocity.z
	var measured_period_s := NAN
	if zero_crossing_ticks.size() >= 3:
		measured_period_s = (
			float(zero_crossing_ticks[2] - zero_crossing_ticks[0]) / float(PHYSICS_HZ)
		)
	var analytic_period_s := 2.0 * PI * sqrt(2.0 / (3.0 * 9.8))
	var result := {
		"ok": true,
		"failure_code": "",
		"mass_inertia_round_trip":
		(
			absf(free_fall.mass - 2.0) <= 1.0e-12
			and free_fall.inertia.is_equal_approx(Vector3(0.10, 0.20, 0.30))
		),
		"free_fall_bounded":
		(
			absf((3.0 - free_fall_y_60) - 0.5 * 9.8 * 0.5 * 0.5) <= 0.08
			and absf(free_fall_vy_60 + 9.8 * 0.5) <= 0.12
		),
		"unconstrained_integration_bounded":
		(
			absf((integration_x_120 + 3.0) - 1.25) <= 0.02
			and absf(integration_vx_120 - 1.25) <= 0.02
		),
		"damping_response_bounded":
		(
			damped_vx_120 > 0.0
			and damped_vx_120 < 0.8
			and damped_wz_120 > 0.0
			and damped_wz_120 < 1.2
		),
		"pendulum_response_bounded":
		(
			zero_crossing_ticks.size() >= 3
			and is_finite(measured_period_s)
			and absf(measured_period_s - analytic_period_s) / analytic_period_s <= 0.10
			and maximum_pendulum_radius_error_m <= 5.0e-3
			and not pendulum_joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR)
		),
		"free_fall_y_60_m": free_fall_y_60,
		"free_fall_vy_60_m_s": free_fall_vy_60,
		"integration_x_120_m": integration_x_120,
		"integration_vx_120_m_s": integration_vx_120,
		"damped_vx_120_m_s": damped_vx_120,
		"damped_wz_120_rad_s": damped_wz_120,
		"zero_crossing_ticks": zero_crossing_ticks,
		"measured_pendulum_period_s": measured_period_s,
		"analytic_pendulum_period_s": analytic_period_s,
		"maximum_pendulum_radius_error_m": maximum_pendulum_radius_error_m,
		"motor_application_count": 0,
		"world_build_count": 1,
		"physical_acceptance_authority": false,
	}
	viewport.queue_free()
	await physics_frame
	return result


func _run_c4_actuator_fixtures() -> Dictionary:
	var viewport := _new_viewport("SdkC4ActuatorViewport")
	var world := Node3D.new()
	world.name = "SdkC4ActuatorWorld"
	viewport.add_child(world)
	var high := _motor_rig(world, "HighImpulse", Vector3(0.0, 2.0, 0.0), 0.05)
	var low := _motor_rig(world, "LowImpulse", Vector3(3.0, 2.0, 0.0), 0.00005)
	await process_frame
	await physics_frame
	for rig_value in [high, low]:
		var rig: Dictionary = rig_value
		var child: RigidBody3D = rig["child"]
		child.freeze = false
		child.sleeping = false
		child.position = rig["initial_child_position"]
		child.quaternion = Quaternion.IDENTITY
		child.linear_velocity = Vector3.ZERO
		child.angular_velocity = Vector3.ZERO
	var high_command: Dictionary = WaveGaitScript._command_hinge_motor(
		high["state"],
		0.6,
		-1.0,
		8.0,
		0.65,
		1.0,
		true,
	)
	var low_joint: HingeJoint3D = low["joint"]
	low_joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, -1.0)
	var high_joint: HingeJoint3D = high["joint"]
	var realized_high_target_velocity := high_joint.get_param(
		HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY
	)
	var realized_high_impulse := high_joint.get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE)
	var realized_low_impulse := low_joint.get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE)
	var parameters_round_trip := (
		absf(realized_high_target_velocity + 1.0) <= 1.0e-7
		and absf(realized_high_impulse - 0.05) <= 1.0e-7
		and absf(realized_low_impulse - 0.00005) <= 1.0e-9
	)
	var high_speed_12 := NAN
	var low_speed_12 := NAN
	var high_angle_60 := NAN
	var high_speed_60 := NAN
	for tick in 60:
		await physics_frame
		if tick + 1 == 12:
			high_speed_12 = absf(WaveGaitScript._joint_rate_rad_s(high["state"]))
			low_speed_12 = absf(WaveGaitScript._joint_rate_rad_s(low["state"]))
		if tick + 1 == 60:
			high_angle_60 = WaveGaitScript._joint_angle_rad(high["state"])
			high_speed_60 = absf(WaveGaitScript._joint_rate_rad_s(high["state"]))
	var result := {
		"ok": true,
		"failure_code": "",
		"parameters_round_trip": parameters_round_trip,
		"pd_conversion_bounded":
		(
			bool(high_command.get("actuation_applied", false))
			and absf(float(high_command["target_velocity_rad_s"]) + 1.0) <= 1.0e-12
			and float(high_command["maximum_target_speed_rad_s"]) == 1.0
		),
		"impulse_response_ordered":
		(
			is_finite(high_speed_12)
			and is_finite(low_speed_12)
			and high_speed_12 > low_speed_12 + 0.02
		),
		"physical_response_bounded":
		(
			is_finite(high_angle_60)
			and is_finite(high_speed_60)
			and high_angle_60 > 0.05
			and absf(0.6 - high_angle_60) < 0.55
			and high_speed_60 <= 1.15
		),
		"high_speed_12_rad_s": high_speed_12,
		"low_speed_12_rad_s": low_speed_12,
		"high_angle_60_rad": high_angle_60,
		"high_speed_60_rad_s": high_speed_60,
		"high_impulse_nms": 0.05,
		"low_impulse_nms": 0.00005,
		"realized_high_target_velocity_rad_s": realized_high_target_velocity,
		"realized_high_impulse_nms": realized_high_impulse,
		"realized_low_impulse_nms": realized_low_impulse,
		"world_build_count": 1,
		"physical_acceptance_authority": false,
	}
	viewport.queue_free()
	await physics_frame
	return result


func _new_viewport(viewport_name: String) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = viewport_name
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	return viewport


func _passive_body(
	body_name: String,
	mass_kg: float,
	size_m: Vector3,
	custom_inertia: Vector3,
	gravity_scale: float,
	linear_damp: float,
	angular_damp: float,
) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = body_name
	body.mass = mass_kg
	body.inertia = custom_inertia
	body.gravity_scale = gravity_scale
	body.can_sleep = false
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.freeze = true
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = linear_damp
	body.angular_damp = angular_damp
	body.collision_layer = 0
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_m
	collision.shape = shape
	body.add_child(collision)
	return body


func _motor_rig(
	world: Node3D,
	rig_name: String,
	pivot: Vector3,
	maximum_impulse_nms: float,
) -> Dictionary:
	var parent := RigidBody3D.new()
	parent.name = "%sParent" % rig_name
	parent.position = pivot
	parent.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	parent.freeze = true
	parent.collision_layer = 0
	parent.collision_mask = 0
	world.add_child(parent)
	var child := _passive_body(
		"%sChild" % rig_name,
		1.0,
		Vector3(0.08, 0.8, 0.08),
		Vector3.ZERO,
		0.0,
		0.0,
		0.0,
	)
	var initial_child_position := pivot + Vector3.DOWN * 0.4
	child.position = initial_child_position
	world.add_child(child)
	var joint := HingeJoint3D.new()
	joint.name = "%sHinge" % rig_name
	joint.position = pivot
	joint.basis = Basis(Vector3.DOWN, Vector3.RIGHT, Vector3.BACK)
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, false)
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, maximum_impulse_nms)
	world.add_child(joint)
	joint.node_a = joint.get_path_to(parent)
	joint.node_b = joint.get_path_to(child)
	return {
		"parent": parent,
		"child": child,
		"joint": joint,
		"initial_child_position": initial_child_position,
		"state":
		{
			"parent": parent,
			"child": child,
			"joint": joint,
			"rest_relative_basis": Basis.IDENTITY,
			"axis_parent_local": Vector3.BACK,
			"axis_child_local": Vector3.BACK,
			"anchor_parent_local": Vector3.ZERO,
			"anchor_child_local": Vector3.UP * 0.4,
		},
	}


func _failure(code: String) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % label)


func _finish() -> void:
	print("\nSDK Godot/Jolt C2-C5 summary: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
