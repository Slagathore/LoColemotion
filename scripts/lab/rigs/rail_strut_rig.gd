class_name LabRailStrutRig
extends RefCounted

## L4.0 rigid carriage/strut/pad body on an explicit vertical scaffold.
##
## A Generic6DOFJoint3D locks world X/Z translation and all rotation while
## leaving world Y translation unlimited. Every motor and spring is explicitly
## disabled. The floor is ordinary unilateral collision geometry.

const ReconstructorScript := preload(
	"res://scripts/lab/mechanics/external_contact_impulse_reconstructor.gd"
)

const LAB_COLLISION_LAYER := 1 << 20
const BODY_ID := "l4_0_rail_strut"
const BODY_MASS_KG := 3.0
const CARRIAGE_SIZE_M := Vector3(0.24, 0.20, 0.24)
const STRUT_SIZE_M := Vector3(0.08, 0.60, 0.08)
const PAD_SIZE_M := Vector3(0.30, 0.08, 0.20)
const BODY_ORIGIN_SUPPORTED_M := Vector3(0.0, 0.78, 0.0)
const PAD_LOCAL_CENTER_M := Vector3(0.0, -0.74, 0.0)
const STRUT_LOCAL_CENTER_M := Vector3(0.0, -0.40, 0.0)
const CARRIAGE_LOCAL_CENTER_M := Vector3.ZERO
const FLOOR_SIZE_M := Vector3(8.0, 1.0, 8.0)


func run(
	tree: SceneTree,
	configuration: Dictionary,
	mode: String
) -> Dictionary:
	var floor_present := mode == "supported_floor"
	if mode not in ["freefall_no_floor", "supported_floor"]:
		return {"ok": false, "failure_code": "RAIL_STRUT_MODE_INVALID"}
	var viewport := SubViewport.new()
	viewport.name = "RailStrut_%s" % mode
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var world := Node3D.new()
	var start_position := BODY_ORIGIN_SUPPORTED_M
	if not floor_present:
		start_position = Vector3(0.0, 2.0, 0.0)
	var body := _build_body(start_position)
	var anchor := _build_anchor(start_position)
	var rail := _build_rail(start_position)
	var floor: StaticBody3D = null
	world.add_child(anchor)
	world.add_child(body)
	world.add_child(rail)
	if floor_present:
		floor = _build_floor()
		world.add_child(floor)
	viewport.add_child(world)
	rail.node_a = rail.get_path_to(anchor)
	rail.node_b = rail.get_path_to(body)
	await tree.process_frame
	await tree.physics_frame
	body.freeze = false
	body.global_position = start_position
	body.quaternion = Quaternion.IDENTITY
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	await tree.physics_frame
	body.global_position = start_position
	body.quaternion = Quaternion.IDENTITY
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO

	var step_s := 1.0 / float(configuration["physics_hz"])
	var sample_count := (
		int(configuration["analysis_ticks"])
		if floor_present
		else int(configuration["freefall_ticks"])
	)
	if floor_present:
		for _tick in int(configuration["settle_ticks"]):
			await tree.physics_frame
		body.sleeping = false
	var initial_position := body.global_position
	var initial_velocity := body.linear_velocity
	var expected_weight := BODY_MASS_KG * _gravity_acceleration_world().length()
	var valid_sample_count := 0
	var contact_samples := 0
	var reconstructed_sum := 0.0
	var maximum_support_error := 0.0
	var maximum_lateral_drift := 0.0
	var maximum_tilt := 0.0
	for _tick in sample_count:
		var before := _momentum_sample(body)
		await tree.physics_frame
		body.sleeping = false
		var after := _momentum_sample(body)
		var known_impulse := BODY_MASS_KG * _gravity_acceleration_world() * step_s
		var reconstruction := ReconstructorScript.reconstruct(
			[before], [after], step_s, known_impulse, Vector3.UP
		)
		if bool(reconstruction.get("reconstruction_valid", false)):
			valid_sample_count += 1
			var load := float(reconstruction["reconstructed_step_average_normal_load_n"])
			reconstructed_sum += load
			if floor_present:
				maximum_support_error = maxf(maximum_support_error, absf(load - expected_weight))
		if floor_present and floor in body.get_colliding_bodies():
			contact_samples += 1
		maximum_lateral_drift = maxf(
			maximum_lateral_drift,
			Vector2(
				body.global_position.x - initial_position.x,
				body.global_position.z - initial_position.z
			).length()
		)
		maximum_tilt = maxf(maximum_tilt, _tilt_rad(body))
	var denominator := float(maxi(valid_sample_count, 1))
	var observed_delta_velocity := body.linear_velocity.y - initial_velocity.y
	var expected_delta_velocity := (
		_gravity_acceleration_world().y * step_s * float(sample_count)
		if not floor_present
		else 0.0
	)
	var summary := {
		"mode": mode,
		"valid_sample_count": valid_sample_count,
		"floor_present": floor_present,
		"floor_contact_fraction": float(contact_samples) / float(maxi(sample_count, 1)),
		"expected_weight_n": expected_weight,
		"expected_delta_velocity_mps": expected_delta_velocity,
		"observed_delta_velocity_mps": observed_delta_velocity,
		"vertical_velocity_error_mps":
		absf(observed_delta_velocity - expected_delta_velocity),
		"mean_reconstructed_external_normal_load_n": reconstructed_sum / denominator,
		"maximum_support_load_error_n": maximum_support_error,
		"final_vertical_speed_mps": body.linear_velocity.y,
		"maximum_lateral_drift_m": maximum_lateral_drift,
		"maximum_tilt_rad": maximum_tilt,
		"rail_contract_exact": _rail_contract_exact(rail),
		"vertical_axis_unlocked": not bool(rail.get("linear_limit_y/enabled")),
		"horizontal_axes_locked":
		bool(rail.get("linear_limit_x/enabled")) and bool(rail.get("linear_limit_z/enabled")),
		"all_rotations_locked":
		(
			bool(rail.get("angular_limit_x/enabled"))
			and bool(rail.get("angular_limit_y/enabled"))
			and bool(rail.get("angular_limit_z/enabled"))
		),
		"motors_disabled": _motors_disabled(rail),
		"springs_disabled": _springs_disabled(rail),
		"active_operation_count": 0,
		"passive_operation_count": 0,
		"controller_root_force_count": 0,
		"body_collision_shape_count": 3,
		"rail_class": rail.get_class(),
		"rail_scaffold_explicit": true,
		"aggregate_external_support_only": true,
	}
	var result := {
		"ok": valid_sample_count == sample_count,
		"summary": summary,
		"body_freeze": body.freeze,
		"body_contact_monitor": body.contact_monitor,
	}
	viewport.queue_free()
	await tree.physics_frame
	return result


static func _build_body(position: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = BODY_ID
	body.mass = BODY_MASS_KG
	body.gravity_scale = 1.0
	body.can_sleep = false
	body.contact_monitor = true
	body.max_contacts_reported = 32
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.collision_layer = LAB_COLLISION_LAYER
	body.collision_mask = LAB_COLLISION_LAYER
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.freeze = true
	body.position = position
	_add_box(body, "carriage_shape", CARRIAGE_SIZE_M, CARRIAGE_LOCAL_CENTER_M)
	_add_box(body, "strut_shape", STRUT_SIZE_M, STRUT_LOCAL_CENTER_M)
	_add_box(body, "pad_shape", PAD_SIZE_M, PAD_LOCAL_CENTER_M)
	var material := PhysicsMaterial.new()
	material.friction = 1.0
	material.bounce = 0.0
	body.physics_material_override = material
	return body


static func _build_anchor(position: Vector3) -> StaticBody3D:
	var anchor := StaticBody3D.new()
	anchor.name = "l4_0_rail_anchor"
	anchor.position = position
	anchor.collision_layer = 0
	anchor.collision_mask = 0
	return anchor


static func _build_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "l4_0_floor"
	floor.position = Vector3(0.0, -0.5, 0.0)
	floor.collision_layer = LAB_COLLISION_LAYER
	floor.collision_mask = LAB_COLLISION_LAYER
	_add_box(floor, "floor_shape", FLOOR_SIZE_M, Vector3.ZERO)
	var material := PhysicsMaterial.new()
	material.friction = 1.0
	material.bounce = 0.0
	floor.physics_material_override = material
	return floor


static func _build_rail(position: Vector3) -> Generic6DOFJoint3D:
	var rail := Generic6DOFJoint3D.new()
	rail.name = "l4_0_vertical_rail"
	rail.position = position
	for axis in ["x", "y", "z"]:
		var linear_enabled: bool = axis != "y"
		rail.set("linear_limit_%s/enabled" % axis, linear_enabled)
		rail.set("linear_limit_%s/lower_distance" % axis, 0.0)
		rail.set("linear_limit_%s/upper_distance" % axis, 0.0)
		rail.set("linear_motor_%s/enabled" % axis, false)
		rail.set("linear_spring_%s/enabled" % axis, false)
		rail.set("angular_limit_%s/enabled" % axis, true)
		rail.set("angular_limit_%s/lower_angle" % axis, 0.0)
		rail.set("angular_limit_%s/upper_angle" % axis, 0.0)
		rail.set("angular_motor_%s/enabled" % axis, false)
		rail.set("angular_spring_%s/enabled" % axis, false)
	return rail


static func _rail_contract_exact(rail: Generic6DOFJoint3D) -> bool:
	return (
		bool(rail.get("linear_limit_x/enabled"))
		and not bool(rail.get("linear_limit_y/enabled"))
		and bool(rail.get("linear_limit_z/enabled"))
		and float(rail.get("linear_limit_x/lower_distance")) == 0.0
		and float(rail.get("linear_limit_x/upper_distance")) == 0.0
		and float(rail.get("linear_limit_z/lower_distance")) == 0.0
		and float(rail.get("linear_limit_z/upper_distance")) == 0.0
		and bool(rail.get("angular_limit_x/enabled"))
		and bool(rail.get("angular_limit_y/enabled"))
		and bool(rail.get("angular_limit_z/enabled"))
		and _motors_disabled(rail)
		and _springs_disabled(rail)
	)


static func _motors_disabled(rail: Generic6DOFJoint3D) -> bool:
	for axis in ["x", "y", "z"]:
		if (
			bool(rail.get("linear_motor_%s/enabled" % axis))
			or bool(rail.get("angular_motor_%s/enabled" % axis))
		):
			return false
	return true


static func _springs_disabled(rail: Generic6DOFJoint3D) -> bool:
	for axis in ["x", "y", "z"]:
		if (
			bool(rail.get("linear_spring_%s/enabled" % axis))
			or bool(rail.get("angular_spring_%s/enabled" % axis))
		):
			return false
	return true


static func _add_box(
	parent: CollisionObject3D,
	name: String,
	size: Vector3,
	local_position: Vector3
) -> void:
	var collision := CollisionShape3D.new()
	collision.name = name
	collision.position = local_position
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	parent.add_child(collision)


static func _momentum_sample(body: RigidBody3D) -> Dictionary:
	return {
		"body_id": BODY_ID,
		"mass_kg": body.mass,
		"linear_velocity_world_mps": body.linear_velocity,
	}


static func _gravity_acceleration_world() -> Vector3:
	var magnitude := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var direction_value: Variant = ProjectSettings.get_setting(
		"physics/3d/default_gravity_vector", Vector3.DOWN
	)
	var direction := direction_value as Vector3 if direction_value is Vector3 else Vector3.DOWN
	return magnitude * direction.normalized()


static func _tilt_rad(body: RigidBody3D) -> float:
	return acos(clampf(body.global_basis.y.normalized().dot(Vector3.UP), -1.0, 1.0))
