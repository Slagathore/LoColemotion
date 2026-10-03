class_name LabFrictionSledRig
extends RefCounted

## L1.1 flat-ground friction fixture.
##
## The sled is deliberately low and wide so sliding should precede tipping,
## but it remains a completely free RigidBody3D: no rail, rotation lock,
## custom integrator, damping, or hidden stabilizing force is present. The
## runner must apply the declared center-of-mass shear force once per physics
## tick and record that operation beside the resulting contact observations.

const ObservedRigidBodyScript := preload(
	"res://scripts/lab/mechanics/observed_rigid_body.gd")
const ContactCapacityScript := preload(
	"res://scripts/lab/mechanics/contact_capacity.gd")

const FIXTURE_ID := "L1.1.friction_sled.v1"
const BODY_ID := &"friction_sled_0"
const FLOOR_ID := &"friction_floor"
const CREATURE_ID := &"friction_sled_creature"
const SUPPORT_ROLE := &"friction_test_pad"
const BODY_SHAPE_ID := &"friction_sled_shape"
const FLOOR_SHAPE_ID := &"friction_floor_shape"
const RUN_ID_V2 := "br3a_l1_1_friction_sled_live"
const CAPTURE_STREAM_ID_V2 := "friction_sled_contact_stream"
const BODY_SIZE_M := Vector3(0.8, 0.2, 0.6)
const BODY_MASS_KG := 4.0
const INITIAL_CLEARANCE_M := 0.01
const FLOOR_TOP_Y_M := 0.0
const FLOOR_SIZE_M := Vector3(20.0, 1.0, 8.0)
const DEFAULT_FRICTION := 0.6
const LAB_COLLISION_LAYER := 1 << 20


static func build(
		capture_clock,
		observer_profile: Dictionary,
		body_parameters: Dictionary = {},
		fixture_parameters: Dictionary = {}) -> Dictionary:
	var errors: Array[Dictionary] = []
	if capture_clock == null:
		_add_error(
			errors,
			"CAPTURE_CLOCK_MISSING",
			"/capture_clock",
			"The friction sled requires a LabCaptureClock")
	if not body_parameters.is_empty():
		_add_error(
			errors,
			"UNSUPPORTED_PARAMETER",
			"/body_parameters",
			"L1.1 pins sled mass and geometry; later cells own those sweeps")
	for key_value in fixture_parameters.keys():
		if String(key_value) != "friction":
			_add_error(
				errors,
				"UNSUPPORTED_PARAMETER",
				"/fixture_parameters/%s" % String(key_value),
				"L1.1 permits only the preregistered one-factor friction change")
	var friction_value: Variant = fixture_parameters.get(
		"friction", DEFAULT_FRICTION)
	var friction := NAN
	if typeof(friction_value) in [TYPE_FLOAT, TYPE_INT]:
		friction = float(friction_value)
	if not is_finite(friction) or friction < 0.0 or friction > 1.0:
		_add_error(
			errors,
			"FRICTION_INVALID",
			"/fixture_parameters/friction",
			"Godot PhysicsMaterial friction must be finite and inside [0, 1]")
	if not bool(observer_profile.get("contacts_enabled", false)):
		_add_error(
			errors,
			"OBS_CONTACT_DISABLED",
			"/observer_profile/contacts_enabled",
			"The friction sled requires contact monitoring")
	var channels: Array = observer_profile.get("channels", [])
	if not channels.has("raw_contacts_v2"):
		_add_error(
			errors,
			"OBSERVER_PROFILE_MISMATCH",
			"/observer_profile/channels",
			"L1.1 requires the semantic raw_contacts_v2 stream")

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
				"The friction-sled raw-contact capacity could not be derived")
	if not errors.is_empty():
		return {
			"ok": false,
			"configuration_valid": false,
			"fixture_id": FIXTURE_ID,
			"configuration_errors": errors,
		}

	var world := Node3D.new()
	world.name = "LabWorld_L1_1_FrictionSled"
	var material := _physics_material(friction)

	var floor := StaticBody3D.new()
	floor.name = "FrictionFloor"
	floor.collision_layer = LAB_COLLISION_LAYER
	floor.collision_mask = LAB_COLLISION_LAYER
	floor.position = Vector3(
		0.0,
		FLOOR_TOP_Y_M - 0.5 * FLOOR_SIZE_M.y,
		0.0)
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
	body.name = "ObservedFrictionSled"
	body.body_id = BODY_ID
	body.creature_id = CREATURE_ID
	body.support_role = SUPPORT_ROLE
	body.part_index = 0
	body.capture_clock = capture_clock
	body.observer_profile = observer_profile.duplicate(true)
	body.run_id = RUN_ID_V2
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
	body.position = Vector3(
		0.0,
		FLOOR_TOP_Y_M + 0.5 * BODY_SIZE_M.y + INITIAL_CLEARANCE_M,
		0.0)
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
		"run_id": RUN_ID_V2,
		"capture_stream_id": CAPTURE_STREAM_ID_V2,
		"body_size_m": BODY_SIZE_M,
		"body_mass_kg": BODY_MASS_KG,
		"initial_center_world_m": body.position,
		"initial_clearance_m": INITIAL_CLEARANCE_M,
		"floor_top_y_m": FLOOR_TOP_Y_M,
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
		"force_application_contract": {
			"method": "RigidBody3D.apply_central_force",
			"force_frame": "world",
			"application_point": "center_of_mass",
			"application_frequency": "once_per_physics_tick",
			"hidden_rotation_constraint": false,
			"hidden_damping": false,
		},
		"configuration_errors": [],
	}


static func _physics_material(friction: float) -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.friction = friction
	material.rough = false
	material.bounce = 0.0
	return material


static func _add_error(
		errors: Array[Dictionary],
		code: String,
		path: String,
		message: String) -> void:
	errors.append({
		"code": code,
		"path": path,
		"message": message,
	})
