class_name LabDiscretizedPadRig
extends RefCounted

## L1.8 one rigid foot-sized pad whose collision footprint is tiled into
## 1/4/16/64/100 equal-area box elements.
##
## The pad is always one RigidBody3D with one mass and one authored footprint;
## only the collision discretization changes. Elements are collision geometry,
## never actuators, muscles, toes, or fingers. Under the frozen
## full_contacts_v2 observation policy the a-priori contact declaration is four
## raw points per element, so 64 and 100 elements exceed the 256-point policy
## ceiling and the contact-enumeration build must refuse instead of silently
## truncating evidence. Those counts remain buildable only under a
## contacts-disabled profile as body-state reconstruction-only cells.

const ObservedRigidBodyScript := preload(
	"res://scripts/lab/mechanics/observed_rigid_body.gd")
const ContactCapacityScript := preload(
	"res://scripts/lab/mechanics/contact_capacity.gd")

const FIXTURE_ID := "L1.8.discretized_pad.v1"
const BODY_ID := &"discretized_pad_0"
const FLOOR_ID := &"discretized_pad_floor"
const CREATURE_ID := &"discretized_pad_creature"
const SUPPORT_ROLE := &"discretized_pad"
const FLOOR_SHAPE_ID := &"discretized_pad_floor_shape"
const RUN_ID_V2 := "br3a_l1_8_discretized_pad_live"
const CAPTURE_STREAM_ID_V2 := "discretized_pad_contact_stream"
const PAD_SIZE_M := Vector3(0.30, 0.08, 0.20)
const PAD_MASS_KG := 2.0
const INITIAL_CLEARANCE_M := 0.002
const FLOOR_SIZE_M := Vector3(10.0, 1.0, 10.0)
const FRICTION := 1.0
const LAB_COLLISION_LAYER := 1 << 20
const EXPECTED_RAW_POINTS_PER_ELEMENT := 4
const SAFETY_MARGIN_RAW_POINTS := 8
const ELEMENT_GRIDS := {
	1: Vector2i(1, 1),
	4: Vector2i(2, 2),
	16: Vector2i(4, 4),
	64: Vector2i(8, 8),
	100: Vector2i(10, 10),
}


static func build(
		capture_clock,
		observer_profile: Dictionary,
		body_parameters: Dictionary = {},
		fixture_parameters: Dictionary = {}) -> Dictionary:
	var errors: Array[Dictionary] = []
	if capture_clock == null:
		_add_error(errors, "CAPTURE_CLOCK_MISSING", "/capture_clock",
			"The discretized-pad fixture requires a LabCaptureClock")
	if not body_parameters.is_empty():
		_add_error(errors, "UNSUPPORTED_PARAMETER", "/body_parameters",
			"L1.8 pins pad mass and collision geometry")
	for key_value in fixture_parameters.keys():
		if String(key_value) != "contact_element_count":
			_add_error(errors, "UNSUPPORTED_PARAMETER",
				"/fixture_parameters/%s" % String(key_value),
				"L1.8 permits only the equal-area contact element count")
	var element_count_value: Variant = fixture_parameters.get(
		"contact_element_count")
	var element_count := (
		int(element_count_value) if element_count_value is int else -1)
	if not ELEMENT_GRIDS.has(element_count):
		_add_error(errors, "ELEMENT_COUNT_INVALID",
			"/fixture_parameters/contact_element_count",
			"Element count must be exactly one of 1, 4, 16, 64, 100")

	var contacts_enabled := bool(
		observer_profile.get("contacts_enabled", false))
	var observation_mode := (
		"raw_contact_pressure_v1" if contacts_enabled
		else "body_state_reconstruction_only_v1")
	if contacts_enabled:
		var channels: Array = observer_profile.get("channels", [])
		if not channels.has("raw_contacts_v2"):
			_add_error(errors, "OBSERVER_PROFILE_MISMATCH",
				"/observer_profile/channels",
				"Contact-mode L1.8 requires raw_contacts_v2 per-point weights")

	var contact_capacity: Dictionary = {}
	var declared_expected_points := 0
	if errors.is_empty() and contacts_enabled:
		declared_expected_points = (
			EXPECTED_RAW_POINTS_PER_ELEMENT * element_count)
		var capacity_result: Dictionary = ContactCapacityScript.derive({
			"body_id": String(BODY_ID),
			"expected_simultaneous_raw_points": declared_expected_points,
			"safety_margin_raw_points": SAFETY_MARGIN_RAW_POINTS,
			"policy_max_cap_per_body": int(observer_profile.get(
				"contact_policy_max_cap_per_body", 256)),
		})
		if bool(capacity_result.get("ok", false)):
			contact_capacity = capacity_result["capacity"]
		else:
			# Surface the derivation's own codes so a caller can distinguish
			# the honest policy-ceiling refusal from a malformed declaration.
			for derive_error_value in capacity_result.get("errors", []):
				errors.append((derive_error_value as Dictionary).duplicate(true))
	if not errors.is_empty():
		return {
			"ok": false,
			"configuration_valid": false,
			"fixture_id": FIXTURE_ID,
			"configuration_errors": errors,
			"contact_element_count": element_count,
			"declared_expected_raw_points": declared_expected_points,
			"observation_mode": observation_mode,
		}

	var grid: Vector2i = ELEMENT_GRIDS[element_count]
	var element_size := Vector3(
		PAD_SIZE_M.x / float(grid.x),
		PAD_SIZE_M.y,
		PAD_SIZE_M.z / float(grid.y))
	var material := _physics_material()
	var world := Node3D.new()
	world.name = "LabWorld_L1_8_DiscretizedPad_%d" % element_count
	var floor := StaticBody3D.new()
	floor.name = "DiscretizedPadFloor"
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
	body.name = "ObservedDiscretizedPad"
	body.body_id = BODY_ID
	body.creature_id = CREATURE_ID
	body.support_role = SUPPORT_ROLE
	body.part_index = 0
	body.capture_clock = capture_clock
	body.observer_profile = observer_profile.duplicate(true)
	body.run_id = "%s_%d" % [RUN_ID_V2, element_count]
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
	body.collision_layer = LAB_COLLISION_LAYER
	body.collision_mask = LAB_COLLISION_LAYER
	body.position = Vector3(
		0.0, 0.5 * PAD_SIZE_M.y + INITIAL_CLEARANCE_M, 0.0)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.physics_material_override = material

	var element_shape_ids: Array[String] = []
	var element_centers_local: Array[Vector3] = []
	for row in grid.y:
		for column in grid.x:
			var element_index := row * grid.x + column
			var element_id := "discretized_pad_element_%03d" % element_index
			var center := Vector3(
				-0.5 * PAD_SIZE_M.x + (float(column) + 0.5) * element_size.x,
				0.0,
				-0.5 * PAD_SIZE_M.z + (float(row) + 0.5) * element_size.z)
			var element_collision := CollisionShape3D.new()
			element_collision.set_meta("lab_shape_id", element_id)
			var element_shape := BoxShape3D.new()
			element_shape.size = element_size
			element_collision.shape = element_shape
			element_collision.position = center
			body.add_child(element_collision)
			element_shape_ids.append(element_id)
			element_centers_local.append(center)
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
		"observation_mode": observation_mode,
		"contact_element_count": element_count,
		"element_grid": grid,
		"element_size_m": element_size,
		"element_area_m2": element_size.x * element_size.z,
		"element_shape_ids": element_shape_ids,
		"element_centers_local_m": element_centers_local,
		"declared_expected_raw_points": declared_expected_points,
		"pad_size_m": PAD_SIZE_M,
		"pad_mass_kg": PAD_MASS_KG,
		"expected_static_normal_load_n": PAD_MASS_KG * 9.8,
		"expected_uniform_element_share_n": (
			PAD_MASS_KG * 9.8 / float(element_count)),
		"support_half_width_x_m": 0.5 * PAD_SIZE_M.x,
		"support_half_width_z_m": 0.5 * PAD_SIZE_M.z,
		"plane_normal_world": Vector3.UP,
		"contact_capacity": contact_capacity,
		"constraint_contract": {
			"hidden_rotation_constraint": false,
			"hidden_translation_constraint": false,
			"hidden_damping": false,
			"custom_integrator": false,
			"external_drive": "gravity_only",
			"single_rigid_pad": true,
			"elements_are_collision_geometry_only": true,
			"elements_are_actuators": false,
		},
		"configuration_errors": [],
	}


static func _physics_material() -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.friction = FRICTION
	material.rough = false
	material.bounce = 0.0
	return material


static func _add_error(
		errors: Array[Dictionary],
		code: String,
		path: String,
		message: String) -> void:
	errors.append({"code": code, "path": path, "message": message})
