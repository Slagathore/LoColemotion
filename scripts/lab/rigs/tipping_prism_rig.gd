class_name LabTippingPrismRig
extends RefCounted

## L1.3 free prism with an authored horizontal center-of-mass offset.
##
## The collision footprint never changes. Each offset is a fresh world, so the
## analytic flat-foot support margin is simply:
##
##     margin = footprint_half_width - abs(custom_com_offset_x)
##
## A positive margin predicts static support. A negative margin predicts a
## gravity-driven rotation about the same-sign x edge. There is no controller,
## rail, rotation lock, damping, custom integrator, impulse, or rescue force.

const ObservedRigidBodyScript := preload(
	"res://scripts/lab/mechanics/observed_rigid_body.gd")
const ContactCapacityScript := preload(
	"res://scripts/lab/mechanics/contact_capacity.gd")

const FIXTURE_ID := "L1.3.tipping_prism.v1"
const BODY_ID := &"tipping_prism_0"
const FLOOR_ID := &"tipping_floor"
const CREATURE_ID := &"tipping_prism_creature"
const SUPPORT_ROLE := &"tipping_test_footprint"
const BODY_SHAPE_ID := &"tipping_prism_shape"
const FLOOR_SHAPE_ID := &"tipping_floor_shape"
const RUN_ID_V2 := "br3a_l1_3_tipping_prism_live"
const CAPTURE_STREAM_ID_V2 := "tipping_prism_contact_stream"
const BODY_SIZE_M := Vector3(0.6, 1.0, 0.8)
const BODY_MASS_KG := 4.0
const INITIAL_CLEARANCE_M := 0.002
const FLOOR_SIZE_M := Vector3(20.0, 1.0, 20.0)
const DEFAULT_FRICTION := 1.0
const MAXIMUM_COM_OFFSET_X_M := 0.45
const LAB_COLLISION_LAYER := 1 << 20


static func build(
		capture_clock,
		observer_profile: Dictionary,
		body_parameters: Dictionary = {},
		fixture_parameters: Dictionary = {}) -> Dictionary:
	var errors: Array[Dictionary] = []
	if capture_clock == null:
		_add_error(errors, "CAPTURE_CLOCK_MISSING", "/capture_clock",
			"The tipping prism requires a LabCaptureClock")
	if not body_parameters.is_empty():
		_add_error(errors, "UNSUPPORTED_PARAMETER", "/body_parameters",
			"L1.3 pins prism mass, collision geometry, and inertia policy")
	for key_value in fixture_parameters.keys():
		if String(key_value) not in ["friction", "custom_com_offset_x_m"]:
			_add_error(
				errors,
				"UNSUPPORTED_PARAMETER",
				"/fixture_parameters/%s" % String(key_value),
				"L1.3 permits only friction and horizontal COM offset")
	var friction := _finite_number(
		fixture_parameters.get("friction", DEFAULT_FRICTION))
	if not is_finite(friction) or friction < 0.0 or friction > 1.0:
		_add_error(errors, "FRICTION_INVALID", "/fixture_parameters/friction",
			"Godot PhysicsMaterial friction must be finite and inside [0, 1]")
	var com_offset_x_m := _finite_number(
		fixture_parameters.get("custom_com_offset_x_m", NAN))
	if not is_finite(com_offset_x_m) \
			or absf(com_offset_x_m) > MAXIMUM_COM_OFFSET_X_M:
		_add_error(
			errors,
			"COM_OFFSET_INVALID",
			"/fixture_parameters/custom_com_offset_x_m",
			"COM offset must be finite and inside the L1.3 [-0.45, 0.45] m range")
	if not bool(observer_profile.get("contacts_enabled", false)):
		_add_error(errors, "OBS_CONTACT_DISABLED",
			"/observer_profile/contacts_enabled",
			"The tipping prism requires contact monitoring")
	var channels: Array = observer_profile.get("channels", [])
	if not channels.has("raw_contacts_v2"):
		_add_error(errors, "OBSERVER_PROFILE_MISMATCH",
			"/observer_profile/channels",
			"L1.3 requires per-point raw_contacts_v2 impulses for center of pressure")

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
				"The tipping-prism raw-contact capacity could not be derived")
	if not errors.is_empty():
		return {
			"ok": false,
			"configuration_valid": false,
			"fixture_id": FIXTURE_ID,
			"configuration_errors": errors,
		}

	var material := _physics_material(friction)
	var world := Node3D.new()
	world.name = "LabWorld_L1_3_TippingPrism_%s" % str(com_offset_x_m)

	var floor := StaticBody3D.new()
	floor.name = "TippingFloor"
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
	body.name = "ObservedTippingPrism"
	body.body_id = BODY_ID
	body.creature_id = CREATURE_ID
	body.support_role = SUPPORT_ROLE
	body.part_index = 0
	body.capture_clock = capture_clock
	body.observer_profile = observer_profile.duplicate(true)
	body.run_id = "%s_%s" % [RUN_ID_V2, str(com_offset_x_m)]
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
	body.custom_integrator = false
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector3(com_offset_x_m, 0.0, 0.0)
	body.collision_layer = LAB_COLLISION_LAYER
	body.collision_mask = LAB_COLLISION_LAYER
	body.position = Vector3(
		0.0, 0.5 * BODY_SIZE_M.y + INITIAL_CLEARANCE_M, 0.0)
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

	var half_width_m := 0.5 * BODY_SIZE_M.x
	# The rig world is authored at identity but is not inside SceneTree yet.
	# Use its local transform here; asking Node3D for global_transform before
	# tree entry emits an engine error and returns an invalid identity fallback.
	var initial_center_of_mass_world: Vector3 = (
		body.transform * body.center_of_mass)
	var support_footprint_world := [
		Vector3(-half_width_m, 0.0, -0.5 * BODY_SIZE_M.z),
		Vector3(half_width_m, 0.0, -0.5 * BODY_SIZE_M.z),
		Vector3(half_width_m, 0.0, 0.5 * BODY_SIZE_M.z),
		Vector3(-half_width_m, 0.0, 0.5 * BODY_SIZE_M.z),
	]
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
		"body_size_m": BODY_SIZE_M,
		"body_mass_kg": BODY_MASS_KG,
		"custom_com_offset_x_m": com_offset_x_m,
		"initial_center_of_mass_world_m": initial_center_of_mass_world,
		"support_footprint_world_m": support_footprint_world,
		"support_half_width_m": half_width_m,
		"analytic_support_margin_m": half_width_m - absf(com_offset_x_m),
		"analytic_inside_support": absf(com_offset_x_m) <= half_width_m,
		"expected_tip_direction_x": signf(com_offset_x_m),
		"plane_origin_world_m": Vector3.ZERO,
		"plane_normal_world": Vector3.UP,
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
			"custom_integrator": false,
			"external_drive": "gravity_only",
			"center_of_mass_changed_during_trial": false,
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
