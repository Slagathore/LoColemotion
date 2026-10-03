class_name LabMassRatioStackRig
extends RefCounted

## L1.7 two-body contact stack with fixed total mass and directed mass ratio.
##
## The fixture redistributes the same 2 kg between geometrically identical
## bottom/top boxes. That changes mass ratio without changing total gravity
## load, footprint, height, material, timestep, or solver settings. There are
## no joints: articulated mass-ratio behavior remains a later experiment.

const ObservedRigidBodyScript := preload(
	"res://scripts/lab/mechanics/observed_rigid_body.gd")
const ContactCapacityScript := preload(
	"res://scripts/lab/mechanics/contact_capacity.gd")

const FIXTURE_ID := "L1.7.mass_ratio_stack.v1"
const FLOOR_ID := &"mass_ratio_floor"
const FLOOR_SHAPE_ID := &"mass_ratio_floor_shape"
const BOTTOM_BODY_ID := &"mass_ratio_bottom"
const TOP_BODY_ID := &"mass_ratio_top"
const BOTTOM_SHAPE_ID := &"mass_ratio_bottom_shape"
const TOP_SHAPE_ID := &"mass_ratio_top_shape"
const SYSTEM_CREATURE_ID := &"mass_ratio_stack_system"
const BOX_SIZE_M := Vector3(0.5, 0.2, 0.5)
const TOTAL_MASS_KG := 2.0
const INITIAL_GAP_M := 0.001
const FLOOR_SIZE_M := Vector3(8.0, 1.0, 8.0)
const MINIMUM_RATIO := 1.0
const MAXIMUM_RATIO := 1024.0
const LAB_COLLISION_LAYER := 1 << 20
const RUN_ID_V2 := "br3a_l1_7_mass_ratio_live"
const CAPTURE_STREAM_ID_V2 := "mass_ratio_contact_stream"


static func build(
		capture_clock,
		observer_profile: Dictionary,
		body_parameters: Dictionary = {},
		fixture_parameters: Dictionary = {}) -> Dictionary:
	var errors: Array[Dictionary] = []
	if capture_clock == null:
		_add_error(errors, "CAPTURE_CLOCK_MISSING", "/capture_clock",
			"The mass-ratio stack requires a LabCaptureClock")
	if not body_parameters.is_empty():
		_add_error(errors, "UNSUPPORTED_PARAMETER", "/body_parameters",
			"L1.7 pins total mass and equal collision geometry")
	for key_value in fixture_parameters.keys():
		if String(key_value) not in ["heavy_to_light_ratio", "heavy_body"]:
			_add_error(errors, "UNSUPPORTED_PARAMETER",
				"/fixture_parameters/%s" % String(key_value),
				"L1.7 permits only directed mass-ratio selection")
	var ratio := _finite_number(fixture_parameters.get(
		"heavy_to_light_ratio", NAN))
	var heavy_body := String(fixture_parameters.get("heavy_body", ""))
	if not is_finite(ratio) \
			or ratio < MINIMUM_RATIO or ratio > MAXIMUM_RATIO:
		_add_error(errors, "MASS_RATIO_INVALID",
			"/fixture_parameters/heavy_to_light_ratio",
			"Heavy-to-light ratio must be finite and inside [1, 1024]")
	if heavy_body not in ["neutral", "bottom", "top"]:
		_add_error(errors, "HEAVY_BODY_INVALID",
			"/fixture_parameters/heavy_body",
			"heavy_body must be neutral, bottom, or top")
	if is_finite(ratio):
		if is_equal_approx(ratio, 1.0) and heavy_body != "neutral":
			_add_error(errors, "MASS_RATIO_DIRECTION_INVALID",
				"/fixture_parameters/heavy_body",
				"The 1:1 control must use neutral direction")
		elif ratio > 1.0 and heavy_body == "neutral":
			_add_error(errors, "MASS_RATIO_DIRECTION_INVALID",
				"/fixture_parameters/heavy_body",
				"Unequal masses require an explicit heavy body")
	if not bool(observer_profile.get("contacts_enabled", false)):
		_add_error(errors, "OBS_CONTACT_DISABLED",
			"/observer_profile/contacts_enabled",
			"The mass-ratio stack requires contact monitoring")
	var channels: Array = observer_profile.get("channels", [])
	if not channels.has("raw_contacts_v2"):
		_add_error(errors, "OBSERVER_PROFILE_MISMATCH",
			"/observer_profile/channels",
			"L1.7 requires semantic per-point raw contact observations")

	var contact_capacities: Array = []
	if errors.is_empty():
		for body_id_value in [BOTTOM_BODY_ID, TOP_BODY_ID]:
			var capacity_result: Dictionary = ContactCapacityScript.derive({
				"body_id": String(body_id_value),
				"expected_simultaneous_raw_points": 8,
				"safety_margin_raw_points": 8,
				"policy_max_cap_per_body": int(observer_profile.get(
					"contact_policy_max_cap_per_body", 256)),
			})
			if not bool(capacity_result.get("ok", false)):
				_add_error(errors, "CONTACT_CAPACITY_DERIVATION_FAILED",
					"/bodies/%s/contact_capacity" % String(body_id_value),
					"A mass-ratio body contact cap could not be derived")
				break
			contact_capacities.append(capacity_result["capacity"])
	if not errors.is_empty():
		return {
			"ok": false,
			"configuration_valid": false,
			"fixture_id": FIXTURE_ID,
			"configuration_errors": errors,
		}

	var light_mass := TOTAL_MASS_KG / (1.0 + ratio)
	var heavy_mass := TOTAL_MASS_KG - light_mass
	var bottom_mass := (
		TOTAL_MASS_KG * 0.5
		if heavy_body == "neutral"
		else heavy_mass if heavy_body == "bottom" else light_mass)
	var top_mass := TOTAL_MASS_KG - bottom_mass
	var material := _physics_material()
	var world := Node3D.new()
	world.name = "LabWorld_L1_7_MassRatio_%s_%s" % [
		heavy_body, str(ratio)]
	var floor := _floor(material)
	world.add_child(floor)

	var bottom = _body(
		"ObservedMassRatioBottom",
		BOTTOM_BODY_ID,
		BOTTOM_SHAPE_ID,
		&"mass_ratio_support",
		0,
		bottom_mass,
		0.5 * BOX_SIZE_M.y + INITIAL_GAP_M,
		capture_clock,
		observer_profile,
		contact_capacities[0],
		material,
		heavy_body,
		ratio)
	var top = _body(
		"ObservedMassRatioTop",
		TOP_BODY_ID,
		TOP_SHAPE_ID,
		&"mass_ratio_load",
		1,
		top_mass,
		1.5 * BOX_SIZE_M.y + 2.0 * INITIAL_GAP_M,
		capture_clock,
		observer_profile,
		contact_capacities[1],
		material,
		heavy_body,
		ratio)
	world.add_child(bottom)
	world.add_child(top)

	return {
		"ok": true,
		"configuration_valid": true,
		"fixture_id": FIXTURE_ID,
		"world": world,
		"floor": floor,
		"floor_id": String(FLOOR_ID),
		"bottom_body": bottom,
		"top_body": top,
		"bodies": [bottom, top],
		"bottom_body_id": String(BOTTOM_BODY_ID),
		"top_body_id": String(TOP_BODY_ID),
		"box_size_m": BOX_SIZE_M,
		"total_mass_kg": TOTAL_MASS_KG,
		"bottom_mass_kg": bottom_mass,
		"top_mass_kg": top_mass,
		"heavy_to_light_ratio": ratio,
		"heavy_body": heavy_body,
		"expected_center_heights_m": [
			0.5 * BOX_SIZE_M.y,
			1.5 * BOX_SIZE_M.y,
		],
		"expected_raw_bottom_load_fraction": bottom_mass / TOTAL_MASS_KG,
		"initial_gap_m": INITIAL_GAP_M,
		"contact_capacities": contact_capacities,
		"constraint_contract": {
			"hidden_rotation_constraint": false,
			"hidden_translation_constraint": false,
			"hidden_damping": false,
			"sleep_allowed_per_body": false,
			"custom_integrator": false,
			"external_drive": "gravity_only",
			"joint_count": 0,
			"fixed_total_mass": true,
			"equal_collision_geometry": true,
		},
		"configuration_errors": [],
	}


static func _floor(material: PhysicsMaterial) -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "MassRatioFloor"
	floor.collision_layer = LAB_COLLISION_LAYER
	floor.collision_mask = LAB_COLLISION_LAYER
	floor.position = Vector3(0.0, -0.5 * FLOOR_SIZE_M.y, 0.0)
	floor.physics_material_override = material
	floor.set_meta("lab_body_id", String(FLOOR_ID))
	floor.set_meta("lab_surface_id", String(FLOOR_ID))
	floor.set_meta("lab_surface_tag", "lab_ground")
	floor.set_meta("lab_surface_layer", 1)
	var collision := CollisionShape3D.new()
	collision.set_meta("lab_shape_id", String(FLOOR_SHAPE_ID))
	var shape := BoxShape3D.new()
	shape.size = FLOOR_SIZE_M
	collision.shape = shape
	floor.add_child(collision)
	return floor


static func _body(
		body_name: String,
		body_id: StringName,
		shape_id: StringName,
		role: StringName,
		part_index: int,
		mass_kg: float,
		initial_height_m: float,
		capture_clock,
		observer_profile: Dictionary,
		contact_capacity: Dictionary,
		material: PhysicsMaterial,
		heavy_body: String,
		ratio: float):
	var body = ObservedRigidBodyScript.new()
	body.name = body_name
	body.body_id = body_id
	body.creature_id = SYSTEM_CREATURE_ID
	body.support_role = role
	body.part_index = part_index
	body.capture_clock = capture_clock
	body.observer_profile = observer_profile.duplicate(true)
	body.run_id = "%s_%s_%s" % [RUN_ID_V2, heavy_body, str(ratio)]
	body.capture_stream_id = CAPTURE_STREAM_ID_V2
	body.contact_capacity = contact_capacity
	body.mass = mass_kg
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
	body.position = Vector3(0.0, initial_height_m, 0.0)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.physics_material_override = material
	var collision := CollisionShape3D.new()
	collision.set_meta("lab_shape_id", String(shape_id))
	var shape := BoxShape3D.new()
	shape.size = BOX_SIZE_M
	collision.shape = shape
	body.add_child(collision)
	return body


static func _physics_material() -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.friction = 1.0
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
