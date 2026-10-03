class_name LabInclineBlockRig
extends RefCounted

## L1.2 free block on a statically rotated plane.
##
## Every slope angle is a fresh independent world. The plane is never rotated
## under a live body, and the block has no rail, rotation lock, damping, custom
## integrator, or applied rescue force. Gravity alone supplies the down-slope
## demand, making tan(theta) the analytic shear/normal ratio to compare against
## the empirically measured material threshold.

const ObservedRigidBodyScript := preload(
	"res://scripts/lab/mechanics/observed_rigid_body.gd")
const ContactCapacityScript := preload(
	"res://scripts/lab/mechanics/contact_capacity.gd")

const FIXTURE_ID := "L1.2.incline_block.v1"
const BODY_ID := &"incline_block_0"
const FLOOR_ID := &"incline_plane"
const CREATURE_ID := &"incline_block_creature"
const SUPPORT_ROLE := &"incline_test_pad"
const BODY_SHAPE_ID := &"incline_block_shape"
const FLOOR_SHAPE_ID := &"incline_plane_shape"
const RUN_ID_V2 := "br3a_l1_2_incline_block_live"
const CAPTURE_STREAM_ID_V2 := "incline_block_contact_stream"
const BODY_SIZE_M := Vector3(0.8, 0.2, 0.6)
const BODY_MASS_KG := 4.0
const INITIAL_CLEARANCE_M := 0.01
const FLOOR_SIZE_M := Vector3(30.0, 1.0, 8.0)
const DEFAULT_FRICTION := 0.6
const MAXIMUM_SLOPE_ANGLE_DEG := 60.0
const LAB_COLLISION_LAYER := 1 << 20


static func build(
		capture_clock,
		observer_profile: Dictionary,
		body_parameters: Dictionary = {},
		fixture_parameters: Dictionary = {}) -> Dictionary:
	var errors: Array[Dictionary] = []
	if capture_clock == null:
		_add_error(errors, "CAPTURE_CLOCK_MISSING", "/capture_clock",
			"The incline block requires a LabCaptureClock")
	if not body_parameters.is_empty():
		_add_error(errors, "UNSUPPORTED_PARAMETER", "/body_parameters",
			"L1.2 pins block mass and geometry; later cells own those sweeps")
	for key_value in fixture_parameters.keys():
		if String(key_value) not in ["friction", "slope_angle_deg"]:
			_add_error(
				errors,
				"UNSUPPORTED_PARAMETER",
				"/fixture_parameters/%s" % String(key_value),
				"L1.2 permits only friction and slope-angle variables")
	var friction := _finite_number(
		fixture_parameters.get("friction", DEFAULT_FRICTION))
	if not is_finite(friction) or friction < 0.0 or friction > 1.0:
		_add_error(errors, "FRICTION_INVALID", "/fixture_parameters/friction",
			"Godot PhysicsMaterial friction must be finite and inside [0, 1]")
	var slope_angle_deg := _finite_number(
		fixture_parameters.get("slope_angle_deg", NAN))
	if not is_finite(slope_angle_deg) \
			or slope_angle_deg < 0.0 \
			or slope_angle_deg > MAXIMUM_SLOPE_ANGLE_DEG:
		_add_error(
			errors,
			"SLOPE_ANGLE_INVALID",
			"/fixture_parameters/slope_angle_deg",
			"Slope angle must be finite and inside the L1.2 [0, 60] degree range")
	if not bool(observer_profile.get("contacts_enabled", false)):
		_add_error(
			errors,
			"OBS_CONTACT_DISABLED",
			"/observer_profile/contacts_enabled",
			"The incline block requires contact monitoring")
	var channels: Array = observer_profile.get("channels", [])
	if not channels.has("raw_contacts_v2"):
		_add_error(
			errors,
			"OBSERVER_PROFILE_MISMATCH",
			"/observer_profile/channels",
			"L1.2 requires the semantic raw_contacts_v2 stream")

	var contact_capacity: Dictionary = {}
	if errors.is_empty():
		var capacity_result: Dictionary = ContactCapacityScript.derive({
			"body_id": String(BODY_ID),
			"expected_simultaneous_raw_points": 4,
			"safety_margin_raw_points": 4,
			"policy_max_cap_per_body": int(observer_profile.get(
				"contact_policy_max_cap_per_body", 256)),
		})
		if bool(capacity_result.get("ok", false)):
			contact_capacity = capacity_result["capacity"]
		else:
			_add_error(
				errors,
				"CONTACT_CAPACITY_DERIVATION_FAILED",
				"/observer_profile/contact_cap_mode",
				"The incline raw-contact capacity could not be derived")
	if not errors.is_empty():
		return {
			"ok": false,
			"configuration_valid": false,
			"fixture_id": FIXTURE_ID,
			"configuration_errors": errors,
		}

	var slope_angle_rad := deg_to_rad(slope_angle_deg)
	var slope_basis := Basis(Vector3.FORWARD, slope_angle_rad)
	var plane_normal_world := slope_basis.y.normalized()
	var gravity_direction := Vector3.DOWN
	var downhill_unnormalized := (
		gravity_direction
		- gravity_direction.dot(plane_normal_world) * plane_normal_world)
	var downhill_world := (
		downhill_unnormalized.normalized()
		if downhill_unnormalized.length_squared() > 1.0e-12
		else -slope_basis.x.normalized())
	var cross_slope_world := plane_normal_world.cross(downhill_world).normalized()
	var material := _physics_material(friction)
	var world := Node3D.new()
	world.name = "LabWorld_L1_2_InclineBlock_%sdeg" % str(slope_angle_deg)

	var floor := StaticBody3D.new()
	floor.name = "InclinePlane"
	floor.collision_layer = LAB_COLLISION_LAYER
	floor.collision_mask = LAB_COLLISION_LAYER
	floor.transform = Transform3D(
		slope_basis,
		-0.5 * FLOOR_SIZE_M.y * plane_normal_world)
	floor.physics_material_override = material
	floor.set_meta("lab_body_id", String(FLOOR_ID))
	floor.set_meta("lab_surface_id", String(FLOOR_ID))
	floor.set_meta("lab_surface_tag", "lab_ground")
	floor.set_meta("lab_surface_layer", 1)
	var floor_collision := CollisionShape3D.new()
	floor_collision.set_meta("lab_shape_id", String(FLOOR_SHAPE_ID))
	var floor_shape := BoxShape3D.new()
	floor_shape.size = FLOOR_SIZE_M
	floor_collision.shape = floor_shape
	floor.add_child(floor_collision)
	world.add_child(floor)

	var body = ObservedRigidBodyScript.new()
	body.name = "ObservedInclineBlock"
	body.body_id = BODY_ID
	body.creature_id = CREATURE_ID
	body.support_role = SUPPORT_ROLE
	body.part_index = 0
	body.capture_clock = capture_clock
	body.observer_profile = observer_profile.duplicate(true)
	body.run_id = "%s_%sdeg" % [RUN_ID_V2, str(slope_angle_deg)]
	body.capture_stream_id = CAPTURE_STREAM_ID_V2
	body.contact_capacity = contact_capacity
	body.mass = BODY_MASS_KG
	body.gravity_scale = 1.0
	body.can_sleep = false
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.lock_rotation = false
	body.collision_layer = LAB_COLLISION_LAYER
	body.collision_mask = LAB_COLLISION_LAYER
	body.transform = Transform3D(
		slope_basis,
		(0.5 * BODY_SIZE_M.y + INITIAL_CLEARANCE_M)
			* plane_normal_world)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.physics_material_override = material
	var body_collision := CollisionShape3D.new()
	body_collision.set_meta("lab_shape_id", String(BODY_SHAPE_ID))
	var body_shape := BoxShape3D.new()
	body_shape.size = BODY_SIZE_M
	body_collision.shape = body_shape
	body.add_child(body_collision)
	world.add_child(body)

	return {
		"ok": true,
		"configuration_valid": true,
		"fixture_id": FIXTURE_ID,
		"world": world,
		"body": body,
		"floor": floor,
		"body_id": String(BODY_ID),
		"creature_id": String(CREATURE_ID),
		"support_role": String(SUPPORT_ROLE),
		"floor_id": String(FLOOR_ID),
		"run_id": body.run_id,
		"capture_stream_id": CAPTURE_STREAM_ID_V2,
		"body_size_m": BODY_SIZE_M,
		"body_mass_kg": BODY_MASS_KG,
		"slope_angle_deg": slope_angle_deg,
		"slope_angle_rad": slope_angle_rad,
		"plane_origin_world_m": Vector3.ZERO,
		"plane_normal_world": plane_normal_world,
		"downhill_world": downhill_world,
		"cross_slope_world": cross_slope_world,
		"analytic_tangent_to_normal_ratio": tan(slope_angle_rad),
		"initial_center_world_m": body.position,
		"initial_clearance_m": INITIAL_CLEARANCE_M,
		"contact_cap_per_body": int(
			contact_capacity["configured_cap_per_body"]),
		"contact_capacity": contact_capacity,
		"material_contract": {
			"friction": friction,
			"body_rough": false,
			"floor_rough": false,
			"godot_pair_rule": "minimum_friction_both_nonrough_v1",
			"authored_pair_coefficient": friction,
		},
		"constraint_contract": {
			"hidden_rotation_constraint": false,
			"hidden_translation_constraint": false,
			"hidden_damping": false,
			"external_drive": "gravity_only",
			"plane_rotated_during_trial": false,
		},
		"configuration_errors": [],
	}


static func _physics_material(friction: float) -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.friction = friction
	material.rough = false
	material.bounce = 0.0
	return material


static func _finite_number(value: Variant) -> float:
	return float(value) if typeof(value) in [TYPE_FLOAT, TYPE_INT] else NAN


static func _add_error(
		errors: Array[Dictionary],
		code: String,
		path: String,
		message: String) -> void:
	errors.append({"code": code, "path": path, "message": message})
