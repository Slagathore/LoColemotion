class_name LabControlledFallArrestRig
extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## One planar, two-body BR11 protective-fall fixture.
##
## Both worlds begin from the same falling state. The active world routes a
## pure supervisor/controller request through one finite paired hinge actuator;
## the control routes a zero request through the same command/receipt seam.

const ActuationExecutorScript := preload("res://scripts/lab/actuation_executor.gd")
const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const CommandLedgerScript := preload("res://scripts/lab/command_ledger.gd")
const ExecutionReceiptSinkScript := preload("res://scripts/lab/records/execution_receipt.gd")
const MechanicsBodySampleScript := preload("res://scripts/lab/mechanics/mechanics_body_sample.gd")
const ObservedRigidBodyScript := preload("res://scripts/lab/mechanics/observed_rigid_body.gd")
const JointActuatorScript := preload("res://scripts/lab/mechanics/joint_actuator.gd")
const ControllerScript := preload("res://scripts/lab/mechanics/fall_arrest_controller.gd")
const RoleRegistryScript := preload(
	"res://scripts/lab/mechanics/protective_contact_role_registry.gd"
)
const SupervisorScript := preload("res://scripts/lab/mechanics/fall_arrest_supervisor.gd")
const WholeBodyRotationalStateScript := preload(
	"res://scripts/lab/mechanics/whole_body_rotational_state.gd"
)

const TORSO_ID := "br11_torso"
const PROTECTIVE_ID := "br11_protective_link"
const TORSO_SHAPE_ID := "br11_torso_core_shape"
const PROTECTIVE_SHAPE_ID := "br11_protective_distal_shape"
const FLOOR_ID := "br11_floor"
const JOINT_ID := "br11_protective_hinge"
const LAB_COLLISION_LAYER := 1
const AXIS_WORLD := Vector3(0.0, 0.0, 1.0)


func run_trial(
	tree: SceneTree,
	contract: Dictionary,
	controller: Dictionary,
	actuator_spec: Dictionary,
	arrest_enabled: bool
) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "BR11_ControlledFall_%s" % ("active" if arrest_enabled else "control")
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var world := Node3D.new()
	world.name = "BR11_ControlledFallWorld"
	var clock = CaptureClockScript.new()
	var torso_size := _vector3(contract["torso_size_m"])
	var torso_position := _vector3(contract["initial_torso_position_m"])
	var torso_angle := float(contract["initial_torso_angle_rad"])
	var relative_angle := float(contract["initial_protective_relative_angle_rad"])
	var protective_length := float(contract["protective_length_m"])
	var protective_width := float(contract["protective_width_m"])
	var hinge_position := torso_position + _rotated_x(torso_angle, torso_size.x * 0.42)
	var protective_angle := torso_angle + relative_angle
	var protective_position := (
		hinge_position + _rotated_x(protective_angle, protective_length * 0.5)
	)
	var profile := {
		"profile_id": "br11_controlled_fall_contacts_v1",
		"contacts_enabled": true,
		"contact_cap_per_body": 8,
		"channels": [],
	}
	var torso = _observed_box(
		TORSO_ID,
		TORSO_SHAPE_ID,
		"core_impact",
		torso_position,
		torso_angle,
		float(contract["torso_mass_kg"]),
		torso_size,
		clock,
		profile
	)
	var protective = _observed_box(
		PROTECTIVE_ID,
		PROTECTIVE_SHAPE_ID,
		"protective_distal",
		protective_position,
		protective_angle,
		float(contract["protective_mass_kg"]),
		Vector3(protective_length, protective_width, torso_size.z * 0.75),
		clock,
		profile
	)
	torso.run_id = _run_id(arrest_enabled)
	protective.run_id = _run_id(arrest_enabled)
	torso.capture_stream_id = "br11_whole_system"
	protective.capture_stream_id = "br11_whole_system"
	var floor := _build_floor(float(contract["floor_friction"]))
	var anchor := _build_anchor(torso_position)
	var guide := _build_planar_guide(torso_position)
	var hinge := _build_hinge(hinge_position)
	for node in [anchor, torso, protective, guide, hinge, floor]:
		world.add_child(node)
	viewport.add_child(world)
	guide.node_a = guide.get_path_to(anchor)
	guide.node_b = guide.get_path_to(torso)
	hinge.node_a = hinge.get_path_to(torso)
	hinge.node_b = hinge.get_path_to(protective)
	torso.add_collision_exception_with(protective)
	protective.add_collision_exception_with(torso)
	await tree.process_frame
	await tree.physics_frame
	torso.freeze = true
	protective.freeze = true
	_reset_body(torso, torso_position, torso_angle)
	_reset_body(protective, protective_position, protective_angle)
	torso.freeze = false
	protective.freeze = false
	torso.sleeping = false
	protective.sleeping = false
	var initial_linear_velocity := _vector3(contract["initial_linear_velocity_m_s"])
	torso.linear_velocity = initial_linear_velocity
	protective.linear_velocity = initial_linear_velocity
	torso.angular_velocity = Vector3(0.0, 0.0, float(contract["initial_angular_velocity_rad_s"]))
	protective.angular_velocity = torso.angular_velocity

	var registry_result := RoleRegistryScript.compile(_role_configuration())
	if not bool(registry_result.get("ok", false)):
		viewport.queue_free()
		await tree.process_frame
		return {"ok": false, "failure_code": "BR11_ROLE_REGISTRY_INVALID"}
	var registry: Dictionary = registry_result["registry"]
	var supervisor = SupervisorScript.new()
	var supervisor_setup := (
		supervisor
		. configure(
			{
				"schema_version": "fall_arrest_supervisor_configuration_v1",
				"supervisor_id": "br11_%s" % ("active" if arrest_enabled else "control"),
				"fallen_confirm_ticks": int(contract["fallen_confirm_ticks"]),
				"automatic_creature_guidance_allowed": false,
			}
		)
	)
	if not bool(supervisor_setup.get("ok", false)):
		viewport.queue_free()
		await tree.process_frame
		return {"ok": false, "failure_code": "BR11_SUPERVISOR_CONFIGURATION_INVALID"}
	var receipt_sink = ExecutionReceiptSinkScript.new(_run_id(arrest_enabled))
	var bodies := {TORSO_ID: torso, PROTECTIVE_ID: protective}
	var total_mass: float = float(torso.mass) + float(protective.mass)
	var gravity := _gravity_acceleration_world().length()
	var step_s := 1.0 / float(contract["physics_hz"])
	var fixture_complete := true
	var fixture_failure_code := ""
	var all_receipts_complete := true
	var executed_ticks := 0
	var first_protective_contact_tick := -1
	var first_core_contact_tick := -1
	var protective_before_core := false
	var peak_predicted_local_core_load := 0.0
	var initial_aggregate: Dictionary = {}
	var pre_core_aggregate: Dictionary = {}
	var previous_aggregate: Dictionary = {}
	var previous_torso_velocity := initial_linear_velocity
	var core_approach_speed := 0.0
	var previous_active := 0.0
	var previous_activation := 1.0
	var actuator_work := 0.0
	var maximum_applied_torque := 0.0
	var maximum_pairing_residual := 0.0
	var actuator_saturation_count := 0
	var fallen_transition_tick := -1
	var final_phase := "MONITOR"
	var stable_fallen_observed := false
	var protective_role_registered := false
	var core_role_registered := false
	var initial_potential := 0.0

	clock.open_epoch(0, 0.0, &"integrate_callback")
	await tree.physics_frame
	clock.close_epoch()
	initial_aggregate = _aggregate(torso, protective, arrest_enabled)
	if not _aggregate_complete(initial_aggregate):
		fixture_complete = false
		fixture_failure_code = "BR11_INITIAL_AGGREGATE_UNAVAILABLE"
	else:
		previous_aggregate = initial_aggregate
		initial_potential = _potential_energy([torso, protective], gravity)

	for tick in range(1, int(contract["trial_ticks"]) + 1):
		if not fixture_complete:
			break
		var torso_contact_before: bool = floor in torso.get_colliding_bodies()
		var protective_contact_before: bool = floor in protective.get_colliding_bodies()
		stable_fallen_observed = _stable_fallen(
			torso,
			protective,
			torso_contact_before,
			float(contract["stable_linear_speed_m_s"]),
			float(contract["stable_angular_speed_rad_s"])
		)
		var supervision := (
			supervisor
			. observe(
				{
					"schema_version": "fall_arrest_supervisor_input_v1",
					"tick": tick,
					"upright_recovery_feasible": false,
					"impact_imminent": tick >= int(contract["fall_arrest_start_tick"]),
					"protective_capacity_available": arrest_enabled,
					"stable_fallen_observed": stable_fallen_observed,
				}
			)
		)
		if not bool(supervision.get("ok", false)):
			fixture_complete = false
			fixture_failure_code = "BR11_SUPERVISOR_OBSERVATION_FAILED"
			break
		final_phase = String(supervision["phase"])
		if final_phase == "FALLEN" and fallen_transition_tick < 0:
			fallen_transition_tick = tick
		var torso_pitch := _pitch(torso)
		var protective_pitch := _pitch(protective)
		var measured_relative_angle := wrapf(protective_pitch - torso_pitch, -PI, PI)
		var measured_relative_rate: float = (
			float(protective.angular_velocity.z) - float(torso.angular_velocity.z)
		)
		var controller_result := (
			ControllerScript
			. resolve(
				controller,
				{
					"schema_version": "fall_arrest_controller_input_v1",
					"tick": tick,
					"supervisor_phase": final_phase,
					"measured_relative_angle_rad": measured_relative_angle,
					"measured_relative_rate_rad_s": measured_relative_rate,
				}
			)
		)
		if not bool(controller_result.get("ok", false)):
			fixture_complete = false
			fixture_failure_code = "BR11_CONTROLLER_RESOLUTION_FAILED"
			break
		var active_components: Dictionary = controller_result["resolution"]["active_components"]
		if not arrest_enabled:
			active_components = {"protective_pd_nm": 0.0}
		var plan := (
			JointActuatorScript
			. resolve_and_plan(
				{
					"schema_version": "joint_actuator_input_v1",
					"tick": tick,
					"joint_id": JOINT_ID,
					"parent_body_id": TORSO_ID,
					"child_body_id": PROTECTIVE_ID,
					"source_id": "br11_controlled_fall_arrest",
					"behavior_state": final_phase,
					"axis_world": AXIS_WORLD,
					"pivot_world": hinge.global_position,
					"angular_velocity_rad_s": measured_relative_rate,
					"active_components": active_components,
					"passive_components": {},
					"previous_active_nm": previous_active,
					"previous_activation": previous_activation,
					"step_s": step_s,
				},
				actuator_spec
			)
		)
		if not bool(plan.get("ok", false)):
			fixture_complete = false
			fixture_failure_code = "BR11_ACTUATOR_PLAN_FAILED"
			break
		var resolution: Dictionary = plan["resolution"]
		var command: Dictionary = plan["command"]
		var ledger = CommandLedgerScript.new()
		fixture_complete = ledger.begin_tick(tick)
		fixture_complete = ledger.queue_joint(command) and fixture_complete
		var envelope := (
			ledger
			. seal(
				{
					"run_id": _run_id(arrest_enabled),
					"command_id": tick,
					"source_frame_id": tick,
					"applied_transition": [tick, tick + 1],
					"mode": "BR11_CONTROLLED_FALL_ARREST",
				}
			)
		)
		var receipt_count_before := receipt_sink.values().size()
		clock.open_epoch(tick, float(tick) * step_s, &"integrate_callback")
		var execution := ActuationExecutorScript.apply_command_envelope(
			envelope, bodies, receipt_sink
		)
		await tree.physics_frame
		clock.close_epoch()
		executed_ticks = tick
		var receipts: Array = receipt_sink.values().slice(receipt_count_before)
		var receipts_match := _receipts_match(
			receipts,
			String(envelope["command_payload_sha256"]),
			command["planned_application_operations"]
		)
		all_receipts_complete = all_receipts_complete and receipts_match
		fixture_complete = (
			fixture_complete
			and bool(execution.get("ok", false))
			and int(execution.get("applied_count", -1)) == 2
			and receipts_match
		)
		previous_active = float(resolution["applied_active_nm"])
		previous_activation = float(resolution["activation_next"])
		actuator_work += float(resolution["applied_total_power_w"]) * step_s
		maximum_applied_torque = maxf(
			maximum_applied_torque, absf(float(resolution["applied_total_nm"]))
		)
		maximum_pairing_residual = maxf(
			maximum_pairing_residual, float(command["diagnostics"]["pairing_residual_nm"])
		)
		actuator_saturation_count += int(
			bool(resolution["active_saturated"]) or bool(resolution["structural_saturated"])
		)
		torso.sleeping = false
		protective.sleeping = false
		var aggregate := _aggregate(torso, protective, arrest_enabled)
		if not _aggregate_complete(aggregate):
			fixture_complete = false
			fixture_failure_code = "BR11_RUNTIME_AGGREGATE_UNAVAILABLE"
			break
		var protective_contact: bool = floor in protective.get_colliding_bodies()
		var core_contact: bool = floor in torso.get_colliding_bodies()
		if protective_contact and first_protective_contact_tick < 0:
			var role_result := (
				RoleRegistryScript
				. classify(
					registry,
					{
						"schema_version": "protective_contact_role_observation_v1",
						"body_id": PROTECTIVE_ID,
						"shape_id": PROTECTIVE_SHAPE_ID,
						"counterparty_surface_tag": "lab_ground",
						"contact_observed": true,
					}
				)
			)
			protective_role_registered = (
				bool(role_result.get("ok", false))
				and bool(role_result.get("protective_contact", false))
			)
			first_protective_contact_tick = tick
		if core_contact and first_core_contact_tick < 0:
			var role_result := (
				RoleRegistryScript
				. classify(
					registry,
					{
						"schema_version": "protective_contact_role_observation_v1",
						"body_id": TORSO_ID,
						"shape_id": TORSO_SHAPE_ID,
						"counterparty_surface_tag": "lab_ground",
						"contact_observed": true,
					}
				)
			)
			core_role_registered = (
				bool(role_result.get("ok", false)) and bool(role_result.get("core_contact", false))
			)
			first_core_contact_tick = tick
			pre_core_aggregate = previous_aggregate
			core_approach_speed = maxf(0.0, -previous_torso_velocity.y)
		protective_before_core = (
			first_protective_contact_tick >= 0
			and first_protective_contact_tick < first_core_contact_tick
		)
		if core_contact:
			peak_predicted_local_core_load = maxf(
				peak_predicted_local_core_load,
				_peak_local_predicted_normal_load(torso.latest_contacts, step_s)
			)
		previous_aggregate = aggregate
		previous_torso_velocity = torso.linear_velocity

	if pre_core_aggregate.is_empty():
		pre_core_aggregate = previous_aggregate
	var final_aggregate := _aggregate(torso, protective, arrest_enabled)
	if not _aggregate_complete(final_aggregate):
		fixture_complete = false
		if fixture_failure_code.is_empty():
			fixture_failure_code = "BR11_FINAL_AGGREGATE_UNAVAILABLE"
	var duration_s := float(executed_ticks) * step_s
	var initial_linear := _vector3(initial_aggregate.get("linear_momentum_world_n_s"))
	var final_linear := _vector3(final_aggregate.get("linear_momentum_world_n_s"))
	var gravity_impulse := Vector3(0.0, -total_mass * gravity * duration_s, 0.0)
	var reconstructed_external_impulse := final_linear - initial_linear - gravity_impulse
	var initial_mechanical := (
		float(initial_aggregate.get("linear_kinetic_energy_j", 0.0))
		+ float(initial_aggregate.get("rotational_kinetic_energy_j", 0.0))
		+ initial_potential
	)
	var final_mechanical := (
		float(final_aggregate.get("linear_kinetic_energy_j", 0.0))
		+ float(final_aggregate.get("rotational_kinetic_energy_j", 0.0))
		+ _potential_energy([torso, protective], gravity)
	)
	var contact_dissipation := initial_mechanical + actuator_work - final_mechanical
	var energy_residual := (
		initial_mechanical + actuator_work - final_mechanical - contact_dissipation
	)
	var final_core_contact: bool = floor in torso.get_colliding_bodies()
	stable_fallen_observed = _stable_fallen(
		torso,
		protective,
		final_core_contact,
		float(contract["stable_linear_speed_m_s"]),
		float(contract["stable_angular_speed_rad_s"])
	)
	var summary := {
		"schema_version": "controlled_fall_arrest_summary_v1",
		"configuration_sha256": contract["configuration_sha256"],
		"actuator_spec_sha256": actuator_spec["spec_sha256"],
		"arrest_enabled": arrest_enabled,
		"fixture_complete": fixture_complete,
		"fixture_failure_code": fixture_failure_code,
		"executed_ticks": executed_ticks,
		"planar_guide_exact": _planar_guide_exact(guide),
		"hinge_exact": _hinge_exact(hinge),
		"all_receipts_complete": all_receipts_complete,
		"angular_momentum_available":
		(
			bool(initial_aggregate.get("angular_momentum_available", false))
			and bool(pre_core_aggregate.get("angular_momentum_available", false))
			and bool(final_aggregate.get("angular_momentum_available", false))
		),
		"protective_role_registered": protective_role_registered,
		"core_role_registered": core_role_registered,
		"first_protective_contact_tick": first_protective_contact_tick,
		"first_core_contact_tick": first_core_contact_tick,
		"protective_before_core": protective_before_core,
		"initial_linear_momentum_world_n_s":
		initial_aggregate.get("linear_momentum_world_n_s", [INF, INF, INF]),
		"pre_core_linear_momentum_world_n_s":
		pre_core_aggregate.get("linear_momentum_world_n_s", [INF, INF, INF]),
		"initial_angular_momentum_about_com_world_n_m_s":
		initial_aggregate.get("angular_momentum_about_com_world_n_m_s", [INF, INF, INF]),
		"pre_core_angular_momentum_about_com_world_n_m_s":
		pre_core_aggregate.get("angular_momentum_about_com_world_n_m_s", [INF, INF, INF]),
		"initial_total_kinetic_energy_j":
		(
			float(initial_aggregate.get("linear_kinetic_energy_j", 0.0))
			+ float(initial_aggregate.get("rotational_kinetic_energy_j", 0.0))
		),
		"pre_core_total_kinetic_energy_j":
		(
			float(pre_core_aggregate.get("linear_kinetic_energy_j", INF))
			+ float(pre_core_aggregate.get("rotational_kinetic_energy_j", INF))
		),
		"core_approach_speed_m_s": core_approach_speed,
		"peak_predicted_local_core_load_n": peak_predicted_local_core_load,
		"reconstructed_external_impulse_world_n_s": _array3(reconstructed_external_impulse),
		"initial_mechanical_energy_j": initial_mechanical,
		"final_mechanical_energy_j": final_mechanical,
		"actuator_work_j": actuator_work,
		"contact_dissipation_j": contact_dissipation,
		"energy_accounting_residual_j": energy_residual,
		"final_supervisor_phase": final_phase,
		"fallen_transition_tick": fallen_transition_tick,
		"stable_fallen_observed": stable_fallen_observed,
		"upright_recovery_observed": false,
		"final_linear_speed_m_s":
		maxf(torso.linear_velocity.length(), protective.linear_velocity.length()),
		"final_angular_speed_rad_s":
		maxf(torso.angular_velocity.length(), protective.angular_velocity.length()),
		"maximum_applied_torque_nm": maximum_applied_torque,
		"maximum_pairing_residual_nm": maximum_pairing_residual,
		"actuator_saturation_count": actuator_saturation_count,
		"root_rescue_operation_count": 0,
		"foot_pin_operation_count": 0,
		"pose_teleport_operation_count": 0,
		"automatic_creature_guidance_operation_count": 0,
		"local_core_load_is_generalized_allocation": false,
		"severity_proxy_is_injury_model": false,
	}
	viewport.queue_free()
	await tree.physics_frame
	return {"ok": true, "summary": summary}


static func _aggregate(torso, protective, arrest_enabled: bool) -> Dictionary:
	var run_id := _run_id(arrest_enabled)
	var torso_projection := MechanicsBodySampleScript.project(
		torso.latest_body_sample, run_id, "br11_whole_system"
	)
	var protective_projection := MechanicsBodySampleScript.project(
		protective.latest_body_sample, run_id, "br11_whole_system"
	)
	if (
		not bool(torso_projection.get("ok", false))
		or not bool(protective_projection.get("ok", false))
	):
		return {}
	return (
		WholeBodyRotationalStateScript
		. from_bodies(
			{
				TORSO_ID: torso_projection["sample"],
				PROTECTIVE_ID: protective_projection["sample"],
			}
		)
	)


static func _aggregate_complete(aggregate: Dictionary) -> bool:
	return (
		bool(aggregate.get("finite", false))
		and bool(aggregate.get("angular_momentum_available", false))
		and _vector3(aggregate.get("linear_momentum_world_n_s")).is_finite()
		and _vector3(aggregate.get("angular_momentum_about_com_world_n_m_s")).is_finite()
		and is_finite(float(aggregate.get("linear_kinetic_energy_j", INF)))
		and is_finite(float(aggregate.get("rotational_kinetic_energy_j", INF)))
	)


static func _role_configuration() -> Dictionary:
	return {
		"schema_version": "protective_contact_role_registry_configuration_v1",
		"registry_id": "br11_controlled_fall_roles",
		"roles":
		[
			{
				"body_id": TORSO_ID,
				"shape_id": TORSO_SHAPE_ID,
				"role": "core_impact",
			},
			{
				"body_id": PROTECTIVE_ID,
				"shape_id": PROTECTIVE_SHAPE_ID,
				"role": "protective_distal",
			},
		],
		"automatic_creature_guidance_allowed": false,
	}


static func _observed_box(
	body_id: String,
	shape_id: String,
	role: String,
	position: Vector3,
	angle: float,
	mass_kg: float,
	size: Vector3,
	clock,
	profile: Dictionary
):
	var body = ObservedRigidBodyScript.new()
	body.name = body_id
	body.body_id = StringName(body_id)
	body.creature_id = &"br11_controlled_fall_fixture"
	body.support_role = StringName(role)
	body.part_index = 0 if body_id == TORSO_ID else 1
	body.capture_clock = clock
	body.observer_profile = profile
	body.position = position
	body.rotation = Vector3(0.0, 0.0, angle)
	body.mass = mass_kg
	body.gravity_scale = 1.0
	body.can_sleep = false
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.freeze = true
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector3.ZERO
	body.inertia = _box_inertia(mass_kg, size)
	body.collision_layer = LAB_COLLISION_LAYER
	body.collision_mask = LAB_COLLISION_LAYER
	var collision := CollisionShape3D.new()
	collision.name = shape_id
	collision.set_meta("lab_shape_id", shape_id)
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


static func _build_floor(friction: float) -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = FLOOR_ID
	floor.position = Vector3(0.0, -0.5, 0.0)
	floor.collision_layer = LAB_COLLISION_LAYER
	floor.collision_mask = LAB_COLLISION_LAYER
	floor.set_meta("lab_surface_id", FLOOR_ID)
	floor.set_meta("lab_surface_tag", "lab_ground")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8.0, 1.0, 8.0)
	collision.shape = shape
	floor.add_child(collision)
	var material := PhysicsMaterial.new()
	material.friction = friction
	material.bounce = 0.0
	floor.physics_material_override = material
	return floor


static func _build_anchor(position: Vector3) -> StaticBody3D:
	var anchor := StaticBody3D.new()
	anchor.name = "br11_planar_guide_anchor"
	anchor.position = position
	anchor.collision_layer = 0
	anchor.collision_mask = 0
	return anchor


static func _build_planar_guide(position: Vector3) -> Generic6DOFJoint3D:
	var guide := Generic6DOFJoint3D.new()
	guide.name = "br11_planar_guide"
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


static func _build_hinge(position: Vector3) -> HingeJoint3D:
	var hinge := HingeJoint3D.new()
	hinge.name = JOINT_ID
	hinge.position = position
	hinge.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
	hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, false)
	return hinge


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


static func _stable_fallen(
	torso, protective, core_contact: bool, maximum_linear_speed: float, maximum_angular_speed: float
) -> bool:
	return (
		core_contact
		and torso.linear_velocity.length() <= maximum_linear_speed
		and protective.linear_velocity.length() <= maximum_linear_speed
		and torso.angular_velocity.length() <= maximum_angular_speed
		and protective.angular_velocity.length() <= maximum_angular_speed
	)


static func _peak_local_predicted_normal_load(contacts: Array, step_s: float) -> float:
	var maximum := 0.0
	for contact_value in contacts:
		var contact: Dictionary = contact_value
		var impulse := _vector3(contact.get("impulse_world_ns"))
		var normal := _vector3(contact.get("normal_world"))
		if impulse.is_finite() and normal.is_finite() and normal.length_squared() > 1.0e-12:
			maximum = maxf(maximum, absf(impulse.dot(normal.normalized())) / step_s)
	return maximum


static func _potential_energy(bodies: Array, gravity: float) -> float:
	var result := 0.0
	for body_value in bodies:
		var body: RigidBody3D = body_value
		result += body.mass * gravity * body.global_position.y
	return result


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


static func _reset_body(body: RigidBody3D, position: Vector3, angle: float) -> void:
	body.position = position
	body.rotation = Vector3(0.0, 0.0, angle)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO


static func _box_inertia(mass_kg: float, size: Vector3) -> Vector3:
	return Vector3(
		mass_kg * (size.y * size.y + size.z * size.z) / 12.0,
		mass_kg * (size.x * size.x + size.z * size.z) / 12.0,
		mass_kg * (size.x * size.x + size.y * size.y) / 12.0
	)


static func _pitch(body: RigidBody3D) -> float:
	var direction := body.global_basis.x.normalized()
	return atan2(direction.y, direction.x)


static func _rotated_x(angle: float, length: float) -> Vector3:
	return Vector3(cos(angle) * length, sin(angle) * length, 0.0)


static func _run_id(arrest_enabled: bool) -> String:
	return "br11_active_arrest" if arrest_enabled else "br11_zero_control"


static func _gravity_acceleration_world() -> Vector3:
	var magnitude := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var direction: Vector3 = ProjectSettings.get_setting(
		"physics/3d/default_gravity_vector", Vector3.DOWN
	)
	return direction.normalized() * magnitude


static func _array3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if not value is Array or (value as Array).size() != 3:
		return Vector3(INF, INF, INF)
	var raw: Array = value
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
