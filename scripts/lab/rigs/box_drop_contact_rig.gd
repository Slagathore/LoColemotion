class_name LabBoxDropContactRig
extends RefCounted

## Minimal BR3A.0 engine-contact fixture.
##
## The legacy full_contacts_v1 path remains the narrow raw positive-contact
## oracle. The append-only full_contacts_v2 path additionally supplies stable
## semantic body/shape metadata and a fixture-derived capacity contract so the
## BR3 canonicalization pipeline can consume the same real Jolt collision.

const ObservedRigidBodyScript := preload(
	"res://scripts/lab/mechanics/observed_rigid_body.gd")
const ContactCapacityScript := preload(
	"res://scripts/lab/mechanics/contact_capacity.gd")

const FIXTURE_ID := "L1.0.box_drop_contact.v1"
const BODY_ID := &"drop_box_0"
const FLOOR_ID := &"lab_floor"
const CREATURE_ID := &"box_drop_creature"
const SUPPORT_ROLE := &"test_support_body"
const BODY_SHAPE_ID := &"drop_box_shape"
const FLOOR_SHAPE_ID := &"lab_floor_shape"
const RUN_ID_V2 := "br3a_box_drop_live_pipeline"
const CAPTURE_STREAM_ID_V2 := "box_drop_contact_stream"
const BODY_SIZE_M := Vector3(0.4, 0.6, 0.3)
const BODY_MASS_KG := 2.0
const INITIAL_CLEARANCE_M := 1.2
const FLOOR_TOP_Y_M := 0.0
const FLOOR_SIZE_M := Vector3(8.0, 1.0, 8.0)
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
			"Box-drop contact capture requires a LabCaptureClock")
	if not body_parameters.is_empty():
		_add_error(
			errors,
			"UNSUPPORTED_PARAMETER",
			"/body_parameters",
			"BR3A.0 pins the box body; parameter sweeps belong to later L1 fixtures")
	if not fixture_parameters.is_empty():
		_add_error(
			errors,
			"UNSUPPORTED_PARAMETER",
			"/fixture_parameters",
			"BR3A.0 pins the floor fixture; parameter sweeps belong to later L1 fixtures")
	if not bool(observer_profile.get("contacts_enabled", false)):
		_add_error(
			errors,
			"OBS_CONTACT_DISABLED",
			"/observer_profile/contacts_enabled",
			"The box-drop oracle requires contact monitoring")
	var channels: Array = observer_profile.get("channels", [])
	var uses_raw_contact_v2 := channels.has("raw_contacts_v2")
	var contact_capacity: Dictionary = {}
	var contact_cap := int(observer_profile.get("contact_cap_per_body", 0))
	if uses_raw_contact_v2:
		var capacity_result: Dictionary = ContactCapacityScript.derive({
			"body_id": String(BODY_ID),
			# A convex box/plane manifold has at most four simultaneous raw
			# points. The second four slots are a preregistered truncation guard.
			"expected_simultaneous_raw_points": 4,
			"safety_margin_raw_points": 4,
			"policy_max_cap_per_body": int(observer_profile.get(
				"contact_policy_max_cap_per_body", 256)),
		})
		if bool(capacity_result.get("ok", false)):
			contact_capacity = capacity_result["capacity"]
			contact_cap = int(contact_capacity["configured_cap_per_body"])
		else:
			_add_error(
				errors,
				"CONTACT_CAPACITY_DERIVATION_FAILED",
				"/observer_profile/contact_cap_mode",
				"The v2 box-drop contact capacity could not be derived")
	elif contact_cap <= 0:
		_add_error(
			errors,
			"OBSERVER_PROFILE_MISMATCH",
			"/observer_profile/contact_cap_per_body",
			"The box-drop oracle requires a positive contact cap")
	if not errors.is_empty():
		return {
			"ok": false,
			"configuration_valid": false,
			"fixture_id": FIXTURE_ID,
			"configuration_errors": errors,
		}

	var world := Node3D.new()
	world.name = "LabWorld_L1_0_BoxDropContact"

	var floor := StaticBody3D.new()
	floor.name = "LabFloor"
	floor.collision_layer = LAB_COLLISION_LAYER
	floor.collision_mask = LAB_COLLISION_LAYER
	floor.position = Vector3(
		0.0,
		FLOOR_TOP_Y_M - 0.5 * FLOOR_SIZE_M.y,
		0.0)
	floor.physics_material_override = _physics_material()
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
	body.name = "ObservedDropBox"
	body.body_id = BODY_ID
	body.creature_id = CREATURE_ID
	body.support_role = SUPPORT_ROLE
	body.part_index = 0
	body.capture_clock = capture_clock
	body.observer_profile = observer_profile.duplicate(true)
	if uses_raw_contact_v2:
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
	body.collision_layer = LAB_COLLISION_LAYER
	body.collision_mask = LAB_COLLISION_LAYER
	body.position = Vector3(
		0.0,
		FLOOR_TOP_Y_M + 0.5 * BODY_SIZE_M.y + INITIAL_CLEARANCE_M,
		0.0)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.physics_material_override = _physics_material()
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
		"run_id": RUN_ID_V2 if uses_raw_contact_v2 else null,
		"capture_stream_id": (
			CAPTURE_STREAM_ID_V2 if uses_raw_contact_v2 else null),
		"body_size_m": BODY_SIZE_M,
		"body_mass_kg": BODY_MASS_KG,
		"initial_center_world_m": body.position,
		"initial_clearance_m": INITIAL_CLEARANCE_M,
		"floor_top_y_m": FLOOR_TOP_Y_M,
		"contact_cap_per_body": contact_cap,
		"contact_capacity": contact_capacity,
		"configuration_errors": [],
	}


static func _physics_material() -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.friction = 0.8
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
