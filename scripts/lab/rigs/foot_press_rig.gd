class_name LabFootPressRig
extends RefCounted

## L1.4 foot-sized free pad under gravity at a known custom COM location.
##
## Static equilibrium predicts CoP_x = projected COM_x and total normal load
## N = mg. Independent fresh worlds move the internal load without moving the
## collision footprint. No clamp, rail, rotation lock, damping, or controller
## is allowed to manufacture equilibrium.

const ObservedRigidBodyScript := preload(
	"res://scripts/lab/mechanics/observed_rigid_body.gd")
const ContactCapacityScript := preload(
	"res://scripts/lab/mechanics/contact_capacity.gd")

const FIXTURE_ID := "L1.4.foot_press.v1"
const BODY_ID := &"foot_press_pad_0"
const FLOOR_ID := &"foot_press_floor"
const CREATURE_ID := &"foot_press_creature"
const SUPPORT_ROLE := &"foot_press_pad"
const BODY_SHAPE_ID := &"foot_press_pad_shape"
const FLOOR_SHAPE_ID := &"foot_press_floor_shape"
const RUN_ID_V2 := "br3a_l1_4_foot_press_live"
const CAPTURE_STREAM_ID_V2 := "foot_press_contact_stream"
const PAD_SIZE_M := Vector3(0.30, 0.08, 0.20)
const PAD_MASS_KG := 2.0
const INITIAL_CLEARANCE_M := 0.002
const FLOOR_SIZE_M := Vector3(10.0, 1.0, 10.0)
const FRICTION := 1.0
const MAXIMUM_COM_OFFSET_X_M := 0.12
const LAB_COLLISION_LAYER := 1 << 20


static func build(
		capture_clock,
		observer_profile: Dictionary,
		body_parameters: Dictionary = {},
		fixture_parameters: Dictionary = {}) -> Dictionary:
	var errors: Array[Dictionary] = []
	if capture_clock == null:
		_add_error(errors, "CAPTURE_CLOCK_MISSING", "/capture_clock",
			"The foot-press fixture requires a LabCaptureClock")
	if not body_parameters.is_empty():
		_add_error(errors, "UNSUPPORTED_PARAMETER", "/body_parameters",
			"L1.4 pins pad mass and collision geometry")
	for key_value in fixture_parameters.keys():
		if String(key_value) != "custom_com_offset_x_m":
			_add_error(errors, "UNSUPPORTED_PARAMETER",
				"/fixture_parameters/%s" % String(key_value),
				"L1.4 permits only the horizontal internal load location")
	var com_offset_x_m := _finite_number(
		fixture_parameters.get("custom_com_offset_x_m", NAN))
	if not is_finite(com_offset_x_m) \
			or absf(com_offset_x_m) > MAXIMUM_COM_OFFSET_X_M:
		_add_error(errors, "COM_OFFSET_INVALID",
			"/fixture_parameters/custom_com_offset_x_m",
			"Foot-pad COM offset must be inside [-0.12, 0.12] m")
	if not bool(observer_profile.get("contacts_enabled", false)):
		_add_error(errors, "OBS_CONTACT_DISABLED",
			"/observer_profile/contacts_enabled",
			"The foot-press fixture requires contact monitoring")
	var channels: Array = observer_profile.get("channels", [])
	if not channels.has("raw_contacts_v2"):
		_add_error(errors, "OBSERVER_PROFILE_MISMATCH",
			"/observer_profile/channels",
			"L1.4 requires raw_contacts_v2 for per-point pressure weights")

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
			_add_error(errors, "CONTACT_CAPACITY_DERIVATION_FAILED",
				"/observer_profile/contact_cap_mode",
				"The foot-pad raw-contact capacity could not be derived")
	if not errors.is_empty():
		return {
			"ok": false,
			"configuration_valid": false,
			"fixture_id": FIXTURE_ID,
			"configuration_errors": errors,
		}

	var material := _physics_material()
	var world := Node3D.new()
	world.name = "LabWorld_L1_4_FootPress_%s" % str(com_offset_x_m)
	var floor := StaticBody3D.new()
	floor.name = "FootPressFloor"
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
	body.name = "ObservedFootPressPad"
	body.body_id = BODY_ID
	body.creature_id = CREATURE_ID
	body.support_role = SUPPORT_ROLE
	body.part_index = 0
	body.capture_clock = capture_clock
	body.observer_profile = observer_profile.duplicate(true)
	body.run_id = "%s_%s" % [RUN_ID_V2, str(com_offset_x_m)]
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
	body.center_of_mass = Vector3(com_offset_x_m, 0.0, 0.0)
	body.collision_layer = LAB_COLLISION_LAYER
	body.collision_mask = LAB_COLLISION_LAYER
	body.position = Vector3(
		0.0, 0.5 * PAD_SIZE_M.y + INITIAL_CLEARANCE_M, 0.0)
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
		"run_id": body.run_id,
		"capture_stream_id": CAPTURE_STREAM_ID_V2,
		"pad_size_m": PAD_SIZE_M,
		"pad_mass_kg": PAD_MASS_KG,
		"custom_com_offset_x_m": com_offset_x_m,
		"expected_static_cop_x_m": com_offset_x_m,
		"expected_static_normal_load_n": PAD_MASS_KG * 9.8,
		"support_half_width_x_m": 0.5 * PAD_SIZE_M.x,
		"support_half_width_z_m": 0.5 * PAD_SIZE_M.z,
		"analytic_support_margin_x_m": (
			0.5 * PAD_SIZE_M.x - absf(com_offset_x_m)),
		"plane_normal_world": Vector3.UP,
		"contact_capacity": contact_capacity,
		"constraint_contract": {
			"hidden_rotation_constraint": false,
			"hidden_translation_constraint": false,
			"hidden_damping": false,
			"custom_integrator": false,
			"external_drive": "gravity_only",
			"center_of_mass_changed_during_trial": false,
		},
		"configuration_errors": [],
	}


static func _physics_material() -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.friction = FRICTION
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
