class_name LabLoadedPadRig
extends RefCounted

## BR3B/L3 single-shape pad under an explicit force-controlled load.
##
## The "carriage" boundary is an authored external force applied by the
## runner once per physics tick. It does not attach a pin, rail, axis lock, or
## hidden motor to the pad. Centered downward force covers L3.0, combined
## centered downward/shear force covers L3.1, and a downward force at a
## declared horizontal offset covers L3.2 rocking.

const ObservedRigidBodyScript := preload("res://scripts/lab/mechanics/observed_rigid_body.gd")
const ContactCapacityScript := preload("res://scripts/lab/mechanics/contact_capacity.gd")

const FIXTURE_ID := "L3.loaded_pad.v1"
const BODY_ID := &"loaded_pad_0"
const FLOOR_ID := &"loaded_pad_floor"
const CREATURE_ID := &"loaded_pad_fixture"
const SUPPORT_ROLE := &"loaded_pad"
const BODY_SHAPE_ID := &"loaded_pad_shape"
const FLOOR_SHAPE_ID := &"loaded_pad_floor_shape"
const RUN_ID_V2 := "br3b_l3_loaded_pad_live"
const CAPTURE_STREAM_ID_V2 := "loaded_pad_contact_stream"
const PAD_SIZE_M := Vector3(0.30, 0.08, 0.20)
const PAD_MASS_KG := 2.0
const INITIAL_CLEARANCE_M := 0.002
const FLOOR_SIZE_M := Vector3(12.0, 1.0, 8.0)
const DEFAULT_FRICTION := 1.0
const LAB_COLLISION_LAYER := 1 << 20


static func build(
	capture_clock,
	observer_profile: Dictionary,
	body_parameters: Dictionary = {},
	fixture_parameters: Dictionary = {}
) -> Dictionary:
	var errors: Array[Dictionary] = []
	if capture_clock == null:
		_add_error(
			errors,
			"CAPTURE_CLOCK_MISSING",
			"/capture_clock",
			"The loaded-pad fixture requires a LabCaptureClock"
		)
	if not body_parameters.is_empty():
		_add_error(
			errors,
			"UNSUPPORTED_PARAMETER",
			"/body_parameters",
			"BR3B pins pad mass, geometry, and centered body mass"
		)
	for key_value in fixture_parameters.keys():
		if String(key_value) != "friction":
			_add_error(
				errors,
				"UNSUPPORTED_PARAMETER",
				"/fixture_parameters/%s" % String(key_value),
				"BR3B permits only the declared material friction"
			)
	var friction_value: Variant = fixture_parameters.get("friction", DEFAULT_FRICTION)
	var friction := (
		float(friction_value) if typeof(friction_value) in [TYPE_FLOAT, TYPE_INT] else NAN
	)
	if not is_finite(friction) or friction < 0.0 or friction > 1.0:
		_add_error(
			errors,
			"FRICTION_INVALID",
			"/fixture_parameters/friction",
			"Godot PhysicsMaterial friction must be finite and inside [0, 1]"
		)
	if not bool(observer_profile.get("contacts_enabled", false)):
		_add_error(
			errors,
			"OBS_CONTACT_DISABLED",
			"/observer_profile/contacts_enabled",
			"The loaded-pad fixture requires contact monitoring"
		)
	var channels: Array = observer_profile.get("channels", [])
	if not channels.has("raw_contacts_v2"):
		_add_error(
			errors,
			"OBSERVER_PROFILE_MISMATCH",
			"/observer_profile/channels",
			"BR3B requires raw_contacts_v2 for pressure and shear observations"
		)

	var contact_capacity: Dictionary = {}
	if errors.is_empty():
		var capacity_result: Dictionary = (
			ContactCapacityScript
			. derive(
				{
					"body_id": String(BODY_ID),
					"expected_simultaneous_raw_points": 4,
					"safety_margin_raw_points": 4,
					"policy_max_cap_per_body":
					int(observer_profile.get("contact_policy_max_cap_per_body", 256)),
				}
			)
		)
		if bool(capacity_result.get("ok", false)):
			contact_capacity = capacity_result["capacity"]
		else:
			_add_error(
				errors,
				"CONTACT_CAPACITY_DERIVATION_FAILED",
				"/observer_profile/contact_cap_mode",
				"The loaded-pad raw-contact capacity could not be derived"
			)
	if not errors.is_empty():
		return {
			"ok": false,
			"configuration_valid": false,
			"fixture_id": FIXTURE_ID,
			"configuration_errors": errors,
		}

	var material := _physics_material(friction)
	var world := Node3D.new()
	world.name = "LabWorld_L3_LoadedPad"

	var floor := StaticBody3D.new()
	floor.name = "LoadedPadFloor"
	floor.collision_layer = LAB_COLLISION_LAYER
	floor.collision_mask = LAB_COLLISION_LAYER
	floor.position = Vector3(0.0, -0.5 * FLOOR_SIZE_M.y, 0.0)
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
	body.name = "ObservedLoadedPad"
	body.body_id = BODY_ID
	body.creature_id = CREATURE_ID
	body.support_role = SUPPORT_ROLE
	body.part_index = 0
	body.capture_clock = capture_clock
	body.observer_profile = observer_profile.duplicate(true)
	body.run_id = RUN_ID_V2
	body.capture_stream_id = CAPTURE_STREAM_ID_V2
	body.contact_capacity = contact_capacity
	body.mass = PAD_MASS_KG
	body.gravity_scale = 1.0
	body.can_sleep = false
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.lock_rotation = false
	body.custom_integrator = false
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector3.ZERO
	body.collision_layer = LAB_COLLISION_LAYER
	body.collision_mask = LAB_COLLISION_LAYER
	body.position = Vector3(0.0, 0.5 * PAD_SIZE_M.y + INITIAL_CLEARANCE_M, 0.0)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.physics_material_override = material
	var body_collision := CollisionShape3D.new()
	body_collision.set_meta("lab_shape_id", String(BODY_SHAPE_ID))
	var body_shape := BoxShape3D.new()
	body_shape.size = PAD_SIZE_M
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
		"floor_id": String(FLOOR_ID),
		"run_id": RUN_ID_V2,
		"capture_stream_id": CAPTURE_STREAM_ID_V2,
		"pad_size_m": PAD_SIZE_M,
		"pad_mass_kg": PAD_MASS_KG,
		"support_half_width_x_m": 0.5 * PAD_SIZE_M.x,
		"support_half_width_z_m": 0.5 * PAD_SIZE_M.z,
		"plane_normal_world": Vector3.UP,
		"contact_capacity": contact_capacity,
		"material_contract":
		{
			"friction": friction,
			"body_rough": false,
			"floor_rough": false,
			"godot_pair_rule": "minimum_friction_both_nonrough_v1",
		},
		"load_application_contract":
		{
			"method": "RigidBody3D.apply_force",
			"force_frame": "world",
			"application_offset_frame": "body_origin_world_aligned",
			"application_frequency": "once_per_physics_tick",
			"downward_only_normal_load": true,
			"hidden_pin_constraint": false,
			"hidden_translation_constraint": false,
			"hidden_rotation_constraint": false,
			"hidden_damping": false,
			"built_in_motor": false,
			"applied_moment_is_only_force_cross_declared_offset": true,
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
	errors: Array[Dictionary], code: String, path: String, message: String
) -> void:
	errors.append({"code": code, "path": path, "message": message})
