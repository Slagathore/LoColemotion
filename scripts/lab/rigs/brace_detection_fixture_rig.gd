class_name LabBraceDetectionFixtureRig
extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## BR8 live passive disturbance matrix.
##
## Three fresh worlds expose a planar-guided rigid body to a central horizontal
## impulse, a slowly tilting ordinary platform, and removal of one of two
## ordinary supports. The detector and supervisor only observe measured body
## transforms, velocities, and contact membership. They apply no response.

const DetectorScript := preload("res://scripts/lab/mechanics/brace_detector.gd")
const SupervisorScript := preload("res://scripts/lab/mechanics/brace_supervisor.gd")

const LAB_COLLISION_LAYER := 1 << 20
const BODY_SIZE := Vector3(0.50, 0.80, 0.20)
const BODY_MASS_KG := 2.0


func run(tree: SceneTree, configuration: Dictionary) -> Dictionary:
	var impulse := await _run_impulse(tree, configuration)
	var tilt := await _run_tilt(tree, configuration)
	var support_loss := await _run_support_loss(tree, configuration)
	return {
		"ok":
		(
			bool(impulse.get("complete", false))
			and bool(tilt.get("complete", false))
			and bool(support_loss.get("complete", false))
		),
		"schema_version": "brace_detection_fixture_summary_v1",
		"impulse": impulse,
		"tilt": tilt,
		"support_loss": support_loss,
		"planar_guide_declared": true,
		"guide_motors_enabled": false,
		"guide_springs_enabled": false,
		"active_brace_controller_present": false,
		"step_controller_present": false,
		"root_rescue_present": false,
		"automatic_creature_guidance": false,
	}


func _run_impulse(tree: SceneTree, configuration: Dictionary) -> Dictionary:
	var fixture := await _build_floor_fixture(tree, "BR8_Impulse")
	if not bool(fixture.get("ok", false)):
		return {"complete": false, "failure_code": "BR8_IMPULSE_BUILD_FAILED"}
	var viewport: SubViewport = fixture["viewport"]
	var body: RigidBody3D = fixture["body"]
	var floor: StaticBody3D = fixture["floor"]
	var guide: Generic6DOFJoint3D = fixture["guide"]
	var supervisor = SupervisorScript.new(int(configuration["release_dwell_ticks"]))
	var initial_stand_samples := 0
	var impulse_count := 0
	var first_brace_tick := -1
	var first_brace_reason := ""
	var first_brace_static_margin := -1.0
	var first_brace_capture_margin := -1.0
	var first_brace_velocity := 0.0
	var first_brace_reaction_viable := false
	var first_transition: Dictionary = {}
	var maximum_tilt := 0.0
	var maximum_speed := 0.0
	var contact_samples := 0
	for tick in int(configuration["impulse_total_ticks"]):
		if tick == int(configuration["impulse_tick"]):
			body.apply_central_impulse(Vector3(float(configuration["impulse_n_s"]), 0.0, 0.0))
			impulse_count += 1
		await tree.physics_frame
		var bearing := floor in body.get_colliding_bodies()
		if bearing:
			contact_samples += 1
		var bounds := _body_bottom_bounds(body, BODY_SIZE)
		var evidence_result := (
			DetectorScript
			. evaluate(
				_detection_request(
					tick,
					body.global_position.x,
					body.linear_velocity.x,
					maxf(0.01, body.global_position.y),
					body.linear_velocity.y,
					0.0,
					float(bounds["minimum_x_m"]),
					float(bounds["maximum_x_m"]),
					1 if bearing else 0,
					not bearing,
					configuration,
				)
			)
		)
		if not bool(evidence_result.get("ok", false)):
			viewport.queue_free()
			await tree.physics_frame
			return {"complete": false, "failure_code": "BR8_IMPULSE_DETECTOR_REFUSED"}
		var evidence: Dictionary = evidence_result["evidence"]
		var state := supervisor.update(tick, evidence)
		if tick < int(configuration["impulse_tick"]) and String(state["state"]) == "STAND":
			initial_stand_samples += 1
		if first_brace_tick < 0 and String(state["state"]) == "BRACE":
			first_brace_tick = tick
			first_brace_reason = String(evidence["dominant_reason"])
			first_brace_static_margin = float(evidence["static_margin_m"])
			first_brace_capture_margin = float(evidence["capture_margin_m"])
			first_brace_velocity = body.linear_velocity.x
			first_brace_reaction_viable = bool(evidence["reaction_viable"])
			first_transition = state["transition"]
		maximum_tilt = maxf(maximum_tilt, _tilt_rad(body))
		maximum_speed = maxf(maximum_speed, absf(body.linear_velocity.x))
	var guide_exact := _guide_exact(guide)
	viewport.queue_free()
	await tree.physics_frame
	return {
		"complete": true,
		"initial_stand_samples": initial_stand_samples,
		"contact_samples": contact_samples,
		"impulse_operation_count": impulse_count,
		"impulse_n_s": float(configuration["impulse_n_s"]),
		"maximum_speed_m_s": maximum_speed,
		"maximum_tilt_rad": maximum_tilt,
		"first_brace_tick": first_brace_tick,
		"first_brace_reason": first_brace_reason,
		"first_brace_static_margin_m": first_brace_static_margin,
		"first_brace_capture_margin_m": first_brace_capture_margin,
		"first_brace_velocity_m_s": first_brace_velocity,
		"first_brace_reaction_viable": first_brace_reaction_viable,
		"first_transition": first_transition,
		"guide_exact": guide_exact,
	}


func _run_tilt(tree: SceneTree, configuration: Dictionary) -> Dictionary:
	var viewport := _viewport(tree, "BR8_Tilt")
	var world := Node3D.new()
	var body := _body("br8_tilt_body", Vector3(0.0, 0.45, 0.0), BODY_SIZE, BODY_MASS_KG)
	var platform := _animatable_platform("br8_tilt_platform", Vector3.ZERO, Vector3(3.0, 0.10, 2.0))
	var anchor := _anchor("br8_tilt_anchor", body.position)
	var guide := _planar_guide("br8_tilt_guide", body.position)
	for node in [anchor, body, guide, platform]:
		world.add_child(node)
	viewport.add_child(world)
	guide.node_a = guide.get_path_to(anchor)
	guide.node_b = guide.get_path_to(body)
	await tree.process_frame
	await tree.physics_frame
	body.freeze = false
	body.sleeping = false
	var supervisor = SupervisorScript.new(int(configuration["release_dwell_ticks"]))
	var initial_stand_samples := 0
	var contact_samples := 0
	var first_precarious_tick := -1
	var first_brace_tick := -1
	var first_brace_angle := -1.0
	var first_brace_static_margin := -1.0
	var first_brace_reason := ""
	var first_static_exhaustion_tick := -1
	var maximum_platform_angle := 0.0
	var maximum_body_tilt := 0.0
	for tick in int(configuration["tilt_total_ticks"]):
		var platform_angle := (
			float(configuration["tilt_maximum_angle_rad"])
			* clampf(
				(
					float(tick - int(configuration["tilt_start_tick"]))
					/ float(configuration["tilt_ramp_ticks"])
				),
				0.0,
				1.0,
			)
		)
		platform.rotation.z = -platform_angle
		await tree.physics_frame
		var bearing := platform in body.get_colliding_bodies()
		if bearing:
			contact_samples += 1
		var bounds := _body_bottom_bounds(body, BODY_SIZE)
		var evidence_result := (
			DetectorScript
			. evaluate(
				_detection_request(
					tick,
					body.global_position.x,
					body.linear_velocity.x,
					maxf(0.01, body.global_position.y - platform.global_position.y),
					body.linear_velocity.y,
					0.0,
					float(bounds["minimum_x_m"]),
					float(bounds["maximum_x_m"]),
					1 if bearing else 0,
					not bearing,
					configuration,
				)
			)
		)
		if not bool(evidence_result.get("ok", false)):
			viewport.queue_free()
			await tree.physics_frame
			return {"complete": false, "failure_code": "BR8_TILT_DETECTOR_REFUSED"}
		var evidence: Dictionary = evidence_result["evidence"]
		var state := supervisor.update(tick, evidence)
		if tick < int(configuration["tilt_start_tick"]) and String(state["state"]) == "STAND":
			initial_stand_samples += 1
		if first_precarious_tick < 0 and String(state["state"]) == "PRECARIOUS":
			first_precarious_tick = tick
		if first_brace_tick < 0 and String(state["state"]) == "BRACE":
			first_brace_tick = tick
			first_brace_angle = platform_angle
			first_brace_static_margin = float(evidence["static_margin_m"])
			first_brace_reason = String(evidence["dominant_reason"])
		if first_static_exhaustion_tick < 0 and float(evidence["static_margin_m"]) < 0.0:
			first_static_exhaustion_tick = tick
		maximum_platform_angle = maxf(maximum_platform_angle, absf(platform_angle))
		maximum_body_tilt = maxf(maximum_body_tilt, _tilt_rad(body))
	var guide_exact := _guide_exact(guide)
	viewport.queue_free()
	await tree.physics_frame
	return {
		"complete": true,
		"initial_stand_samples": initial_stand_samples,
		"contact_samples": contact_samples,
		"first_precarious_tick": first_precarious_tick,
		"first_brace_tick": first_brace_tick,
		"first_brace_platform_angle_rad": first_brace_angle,
		"first_brace_static_margin_m": first_brace_static_margin,
		"first_brace_reason": first_brace_reason,
		"first_static_exhaustion_tick": first_static_exhaustion_tick,
		"maximum_platform_angle_rad": maximum_platform_angle,
		"maximum_body_tilt_rad": maximum_body_tilt,
		"guide_exact": guide_exact,
	}


func _run_support_loss(tree: SceneTree, configuration: Dictionary) -> Dictionary:
	var viewport := _viewport(tree, "BR8_SupportLoss")
	var world := Node3D.new()
	var bridge_size := Vector3(1.0, 0.20, 0.20)
	var body := _body("br8_bridge_body", Vector3(0.0, 0.20, 0.0), bridge_size, 2.0)
	var left := _static_platform(
		"br8_left_support", Vector3(-0.35, 0.05, 0.0), Vector3(0.20, 0.10, 1.0)
	)
	var right := _static_platform(
		"br8_right_support", Vector3(0.35, 0.05, 0.0), Vector3(0.20, 0.10, 1.0)
	)
	var anchor := _anchor("br8_support_loss_anchor", body.position)
	var guide := _planar_guide("br8_support_loss_guide", body.position)
	for node in [anchor, body, guide, left, right]:
		world.add_child(node)
	viewport.add_child(world)
	guide.node_a = guide.get_path_to(anchor)
	guide.node_b = guide.get_path_to(body)
	await tree.process_frame
	await tree.physics_frame
	body.freeze = false
	body.sleeping = false
	var supervisor = SupervisorScript.new(int(configuration["release_dwell_ticks"]))
	var initial_two_support_samples := 0
	var removal_count := 0
	var first_loss_observed_tick := -1
	var first_brace_tick := -1
	var first_brace_reason := ""
	var first_brace_support_count := -1
	var first_transition: Dictionary = {}
	var maximum_tilt := 0.0
	for tick in int(configuration["support_loss_total_ticks"]):
		if tick == int(configuration["support_loss_tick"]):
			right.collision_layer = 0
			right.collision_mask = 0
			right.position.y = -2.0
			removal_count += 1
		await tree.physics_frame
		var contacts: Array[Node3D] = body.get_colliding_bodies()
		var left_bearing := left in contacts
		var right_bearing := right in contacts
		var count := int(left_bearing) + int(right_bearing)
		if tick < int(configuration["support_loss_tick"]) and count == 2:
			initial_two_support_samples += 1
		if (
			tick >= int(configuration["support_loss_tick"])
			and first_loss_observed_tick < 0
			and count < 2
		):
			first_loss_observed_tick = tick
		var bounds := _support_bounds(left_bearing, right_bearing)
		var evidence_result := (
			DetectorScript
			. evaluate(
				_detection_request(
					tick,
					body.global_position.x,
					body.linear_velocity.x,
					maxf(0.01, body.global_position.y - 0.10),
					body.linear_velocity.y,
					0.0,
					float(bounds["minimum_x_m"]),
					float(bounds["maximum_x_m"]),
					count,
					count == 0,
					configuration,
				)
			)
		)
		if not bool(evidence_result.get("ok", false)):
			viewport.queue_free()
			await tree.physics_frame
			return {"complete": false, "failure_code": "BR8_SUPPORT_LOSS_DETECTOR_REFUSED"}
		var evidence: Dictionary = evidence_result["evidence"]
		var state := supervisor.update(tick, evidence)
		if first_brace_tick < 0 and String(state["state"]) == "BRACE":
			first_brace_tick = tick
			first_brace_reason = String(evidence["dominant_reason"])
			first_brace_support_count = count
			first_transition = state["transition"]
		maximum_tilt = maxf(maximum_tilt, _tilt_rad(body))
	var guide_exact := _guide_exact(guide)
	viewport.queue_free()
	await tree.physics_frame
	return {
		"complete": true,
		"initial_two_support_samples": initial_two_support_samples,
		"support_removal_operation_count": removal_count,
		"declared_support_removal_tick": int(configuration["support_loss_tick"]),
		"first_loss_observed_tick": first_loss_observed_tick,
		"first_brace_tick": first_brace_tick,
		"first_brace_reason": first_brace_reason,
		"first_brace_support_count": first_brace_support_count,
		"first_transition": first_transition,
		"maximum_tilt_rad": maximum_tilt,
		"guide_exact": guide_exact,
	}


func _build_floor_fixture(tree: SceneTree, name_value: String) -> Dictionary:
	var viewport := _viewport(tree, name_value)
	var world := Node3D.new()
	var body := _body("%s_body" % name_value, Vector3(0.0, 0.40, 0.0), BODY_SIZE, BODY_MASS_KG)
	var floor := _static_platform(
		"%s_floor" % name_value, Vector3(0.0, -0.05, 0.0), Vector3(8.0, 0.10, 8.0)
	)
	var anchor := _anchor("%s_anchor" % name_value, body.position)
	var guide := _planar_guide("%s_guide" % name_value, body.position)
	for node in [anchor, body, guide, floor]:
		world.add_child(node)
	viewport.add_child(world)
	guide.node_a = guide.get_path_to(anchor)
	guide.node_b = guide.get_path_to(body)
	await tree.process_frame
	await tree.physics_frame
	body.freeze = false
	body.sleeping = false
	return {
		"ok": true,
		"viewport": viewport,
		"body": body,
		"floor": floor,
		"guide": guide,
	}


static func _detection_request(
	tick: int,
	com_x_m: float,
	velocity_x_m_s: float,
	com_height_m: float,
	vertical_velocity_m_s: float,
	clearance_m: float,
	support_min_x_m: float,
	support_max_x_m: float,
	support_count: int,
	airborne: bool,
	configuration: Dictionary
) -> Dictionary:
	return {
		"schema_version": "brace_detection_request_v1",
		"tick": tick,
		"com_x_m": com_x_m,
		"com_velocity_x_m_s": velocity_x_m_s,
		"com_height_m": com_height_m,
		"vertical_velocity_m_s": vertical_velocity_m_s,
		"body_clearance_m": clearance_m,
		"gravity_m_s2": 9.8,
		"support_min_x_m": support_min_x_m,
		"support_max_x_m": support_max_x_m,
		"bearing_support_count": support_count,
		"brace_margin_m": float(configuration["brace_margin_m"]),
		"precarious_margin_m": float(configuration["precarious_margin_m"]),
		"release_margin_m": float(configuration["release_margin_m"]),
		"reaction_time_s": float(configuration["reaction_time_s"]),
		"safety_time_s": float(configuration["safety_time_s"]),
		"brace_trigger_time_s": float(configuration["brace_trigger_time_s"]),
		"precarious_trigger_time_s": float(configuration["precarious_trigger_time_s"]),
		"airborne": airborne,
	}


static func _support_bounds(left_bearing: bool, right_bearing: bool) -> Dictionary:
	if left_bearing and right_bearing:
		return {"minimum_x_m": -0.45, "maximum_x_m": 0.45}
	if left_bearing:
		return {"minimum_x_m": -0.45, "maximum_x_m": -0.25}
	if right_bearing:
		return {"minimum_x_m": 0.25, "maximum_x_m": 0.45}
	return {"minimum_x_m": -0.45, "maximum_x_m": 0.45}


static func _body_bottom_bounds(body: RigidBody3D, size: Vector3) -> Dictionary:
	var left := body.global_transform * Vector3(-0.5 * size.x, -0.5 * size.y, 0.0)
	var right := body.global_transform * Vector3(0.5 * size.x, -0.5 * size.y, 0.0)
	return {
		"minimum_x_m": minf(left.x, right.x),
		"maximum_x_m": maxf(left.x, right.x),
	}


static func _tilt_rad(body: RigidBody3D) -> float:
	return acos(clampf(body.global_basis.y.normalized().dot(Vector3.UP), -1.0, 1.0))


static func _viewport(tree: SceneTree, name_value: String) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = name_value
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	return viewport


static func _body(
	name_value: String, position: Vector3, size: Vector3, mass_kg: float
) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = name_value
	body.position = position
	body.mass = mass_kg
	body.gravity_scale = 1.0
	body.can_sleep = false
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.contact_monitor = true
	body.max_contacts_reported = 16
	body.collision_layer = LAB_COLLISION_LAYER
	body.collision_mask = LAB_COLLISION_LAYER
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.freeze = true
	_add_box(body, size)
	_set_material(body, 1.0)
	return body


static func _static_platform(name_value: String, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_value
	body.position = position
	body.collision_layer = LAB_COLLISION_LAYER
	body.collision_mask = LAB_COLLISION_LAYER
	_add_box(body, size)
	_set_material(body, 1.0)
	return body


static func _animatable_platform(
	name_value: String, position: Vector3, size: Vector3
) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.name = name_value
	body.position = position
	body.collision_layer = LAB_COLLISION_LAYER
	body.collision_mask = LAB_COLLISION_LAYER
	body.sync_to_physics = true
	_add_box(body, size)
	_set_material(body, 1.0)
	return body


static func _anchor(name_value: String, position: Vector3) -> StaticBody3D:
	var anchor := StaticBody3D.new()
	anchor.name = name_value
	anchor.position = position
	anchor.collision_layer = 0
	anchor.collision_mask = 0
	return anchor


static func _planar_guide(name_value: String, position: Vector3) -> Generic6DOFJoint3D:
	var guide := Generic6DOFJoint3D.new()
	guide.name = name_value
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


static func _guide_exact(guide: Generic6DOFJoint3D) -> bool:
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


static func _add_box(parent: CollisionObject3D, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	parent.add_child(collision)


static func _set_material(body: PhysicsBody3D, friction: float) -> void:
	var material := PhysicsMaterial.new()
	material.friction = friction
	material.rough = true
	material.bounce = 0.0
	body.physics_material_override = material
