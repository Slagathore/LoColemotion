class_name LabSolverStackRig
extends RefCounted

## L1.6 equal-mass multi-contact stack for solver-iteration sensitivity.
##
## The fixture must be inserted into a newly constructed World3D after the
## desired Jolt project settings are changed. Ten free boxes create coupled
## floor/body and body/body contact constraints without introducing mass ratio,
## articulation, damping, sleep, clamps, or controller forces.

const ObservedRigidBodyScript := preload(
	"res://scripts/lab/mechanics/observed_rigid_body.gd")
const ContactCapacityScript := preload(
	"res://scripts/lab/mechanics/contact_capacity.gd")

const FIXTURE_ID := "L1.6.solver_stack.v1"
const FLOOR_ID := &"solver_stack_floor"
const FLOOR_SHAPE_ID := &"solver_stack_floor_shape"
const BOX_COUNT := 10
const BOX_SIZE_M := Vector3(0.5, 0.2, 0.5)
const BOX_MASS_KG := 1.0
const INITIAL_GAP_M := 0.001
const FLOOR_SIZE_M := Vector3(8.0, 1.0, 8.0)
const LAB_COLLISION_LAYER := 1 << 20
const RUN_ID_V2 := "br3a_l1_6_solver_stack_live"
const CAPTURE_STREAM_ID_V2 := "solver_stack_contact_stream"


static func build(
		capture_clock,
		observer_profile: Dictionary,
		body_parameters: Dictionary = {},
		fixture_parameters: Dictionary = {}) -> Dictionary:
	var errors: Array[Dictionary] = []
	if capture_clock == null:
		_add_error(errors, "CAPTURE_CLOCK_MISSING", "/capture_clock",
			"The solver stack requires a LabCaptureClock")
	if not body_parameters.is_empty():
		_add_error(errors, "UNSUPPORTED_PARAMETER", "/body_parameters",
			"L1.6 pins equal box mass and geometry")
	if not fixture_parameters.is_empty():
		_add_error(errors, "UNSUPPORTED_PARAMETER", "/fixture_parameters",
			"L1.6 changes solver settings outside the pinned fixture")
	if not bool(observer_profile.get("contacts_enabled", false)):
		_add_error(errors, "OBS_CONTACT_DISABLED",
			"/observer_profile/contacts_enabled",
			"The solver stack requires contact monitoring")
	var channels: Array = observer_profile.get("channels", [])
	if not channels.has("raw_contacts_v2"):
		_add_error(errors, "OBSERVER_PROFILE_MISMATCH",
			"/observer_profile/channels",
			"L1.6 requires semantic per-point raw contact observations")
	var contact_capacities: Array = []
	if errors.is_empty():
		for box_index in BOX_COUNT:
			var body_id := _body_id(box_index)
			var capacity_result: Dictionary = ContactCapacityScript.derive({
				"body_id": body_id,
				# Middle boxes can report four points below and four above.
				"expected_simultaneous_raw_points": 8,
				"safety_margin_raw_points": 8,
				"policy_max_cap_per_body": int(observer_profile.get(
					"contact_policy_max_cap_per_body", 256)),
			})
			if not bool(capacity_result.get("ok", false)):
				_add_error(errors, "CONTACT_CAPACITY_DERIVATION_FAILED",
					"/boxes/%d/contact_capacity" % box_index,
					"The stack raw-contact capacity could not be derived")
				break
			contact_capacities.append(capacity_result["capacity"])
	if not errors.is_empty():
		return {
			"ok": false,
			"configuration_valid": false,
			"fixture_id": FIXTURE_ID,
			"configuration_errors": errors,
		}

	var material := _physics_material()
	var world := Node3D.new()
	world.name = "LabWorld_L1_6_SolverStack"
	var floor := StaticBody3D.new()
	floor.name = "SolverStackFloor"
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

	var bodies: Array = []
	var expected_center_heights_m: Array = []
	for box_index in BOX_COUNT:
		var body = ObservedRigidBodyScript.new()
		var body_id := _body_id(box_index)
		var shape_id := _shape_id(box_index)
		body.name = "ObservedSolverStackBox_%02d" % box_index
		body.body_id = StringName(body_id)
		body.creature_id = StringName("solver_stack_object_%02d" % box_index)
		body.support_role = &"solver_stack_box"
		body.part_index = box_index
		body.capture_clock = capture_clock
		body.observer_profile = observer_profile.duplicate(true)
		body.run_id = "%s_box_%02d" % [RUN_ID_V2, box_index]
		body.capture_stream_id = CAPTURE_STREAM_ID_V2
		body.contact_capacity = contact_capacities[box_index]
		body.mass = BOX_MASS_KG
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
		var expected_height := (
			0.5 * BOX_SIZE_M.y
			+ float(box_index) * BOX_SIZE_M.y)
		expected_center_heights_m.append(expected_height)
		body.position = Vector3(
			0.0,
			expected_height + float(box_index + 1) * INITIAL_GAP_M,
			0.0)
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.physics_material_override = material
		var collision := CollisionShape3D.new()
		collision.set_meta("lab_shape_id", shape_id)
		var shape := BoxShape3D.new()
		shape.size = BOX_SIZE_M
		collision.shape = shape
		body.add_child(collision)
		world.add_child(body)
		bodies.append(body)

	return {
		"ok": true,
		"configuration_valid": true,
		"fixture_id": FIXTURE_ID,
		"world": world,
		"floor": floor,
		"floor_id": String(FLOOR_ID),
		"bodies": bodies,
		"bottom_body": bodies[0],
		"top_body": bodies[bodies.size() - 1],
		"box_count": BOX_COUNT,
		"box_size_m": BOX_SIZE_M,
		"box_mass_kg": BOX_MASS_KG,
		"total_stack_mass_kg": BOX_MASS_KG * float(BOX_COUNT),
		"expected_center_heights_m": expected_center_heights_m,
		"initial_gap_m": INITIAL_GAP_M,
		"contact_capacities": contact_capacities,
		"constraint_contract": {
			"hidden_rotation_constraint": false,
			"hidden_translation_constraint": false,
			"hidden_damping": false,
			"sleep_allowed_per_body": false,
			"custom_integrator": false,
			"external_drive": "gravity_only",
			"equal_mass_only": true,
		},
		"configuration_errors": [],
	}


static func _physics_material() -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.friction = 1.0
	material.rough = false
	material.bounce = 0.0
	return material


static func _body_id(index: int) -> String:
	return "solver_stack_box_%02d" % index


static func _shape_id(index: int) -> String:
	return "solver_stack_shape_%02d" % index


static func _add_error(
		errors: Array[Dictionary],
		code: String,
		path: String,
		message: String) -> void:
	errors.append({"code": code, "path": path, "message": message})
