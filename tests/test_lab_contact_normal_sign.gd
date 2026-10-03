extends SceneTree

## BR3A.0: first positive raw Jolt contact oracle.
##
## Scope is intentionally narrow. This proves that the existing
## ObservedRigidBody -> SensorFrameBuilder -> frame_v1 path reports one real
## box/floor collision with coherent point, normal, and estimated-impulse
## conventions. It does not claim stable contact identity, bearing support, or
## any controller capability.

const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const ObserverProfileScript := preload(
	"res://scripts/lab/observer_profile.gd")
const RigFactoryScript := preload("res://scripts/lab/rig_factory.gd")
const BoxDropRigScript := preload(
	"res://scripts/lab/rigs/box_drop_contact_rig.gd")
const SensorFrameBuilderScript := preload(
	"res://scripts/lab/mechanics/sensor_frame_builder.gd")
const SchemaValidatorScript := preload(
	"res://scripts/lab/schema_validator.gd")

const PHYSICS_TICKS_PER_SECOND := 60
const CAPTURE_FRAME_COUNT := 90
const TIMING_EARLY_TOLERANCE_FRAMES := 1
const TIMING_LATE_TOLERANCE_FRAMES := 2
const NEAR_GROUND_CLEARANCE_M := 0.2
const CONTACT_POINT_TOLERANCE_M := 0.05
const VECTOR_RECONSTRUCTION_TOLERANCE_M := 1.0e-6
const NORMAL_LENGTH_TOLERANCE := 1.0e-4
const NORMAL_UP_DOT_MINIMUM := 0.99
const NORMAL_IMPULSE_TOLERANCE_N_S := 1.0e-7

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== BR3A.0 live Jolt contact normal/sign oracle ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_TICKS_PER_SECOND
	var clock = CaptureClockScript.new()
	var profile: Dictionary = ObserverProfileScript.resolve(
		&"full_contacts_v1")
	var rig: Dictionary = RigFactoryScript.build(
		&"box_drop_contact_v1", clock, profile)
	_check(
		bool(rig.get("ok", false))
			and bool(rig.get("configuration_valid", false)),
		"box-drop fixture accepts the pinned full-contact observer")
	if not bool(rig.get("ok", false)):
		printerr(rig)
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return

	var world := rig["world"] as Node3D
	# Keep the script type here: casting down to RigidBody3D would hide the
	# observer adapter's latest_body_sample/latest_contacts properties.
	var body = rig["body"]
	var floor := rig["floor"] as StaticBody3D
	root.add_child(world)
	var step_s := 1.0 / float(PHYSICS_TICKS_PER_SECOND)
	var frames: Array[Dictionary] = []
	var builder_accepts_every_sample := true
	for frame_id in CAPTURE_FRAME_COUNT:
		clock.open_epoch(
			frame_id,
			float(frame_id + 1) * step_s,
			&"integrate_callback")
		await physics_frame
		clock.close_epoch()
		var builder = SensorFrameBuilderScript.new()
		builder.begin(
			frame_id,
			float(frame_id + 1) * step_s,
			&"integrate_callback",
			&"MEASURE",
			0,
			[BoxDropRigScript.BODY_ID])
		builder_accepts_every_sample = (
			builder.add_body_sample(body.latest_body_sample)
			and builder.add_contacts(body.latest_contacts)
			and builder_accepts_every_sample)
		frames.append(builder.seal())

	_check(
		String(ProjectSettings.get_setting(
			"physics/3d/physics_engine", "")) == "Jolt Physics",
		"fixture runs in the configured Jolt backend")
	_check(builder_accepts_every_sample,
		"every direct-state body/contact sample enters one coherent frame")
	_check(frames.size() == CAPTURE_FRAME_COUNT,
		"the complete box-drop observation window is captured")
	var all_frames_finite := true
	for finite_frame in frames:
		all_frames_finite = (
			bool(finite_frame.get("finite", false)) and all_frames_finite)
	_check(all_frames_finite,
		"every sealed frame remains finite and temporally coherent")

	var first_contact_frame := _first_contact_frame(frames)
	_check(first_contact_frame >= 0,
		"the falling box produces at least one positive direct-state contact")
	if first_contact_frame < 0:
		world.queue_free()
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return

	var measured_gravity_y := _first_body_vector(
		frames[0], "total_gravity_world").y
	var predicted_contact_frame := _predicted_contact_frame(
		float((rig["initial_center_world_m"] as Vector3).y),
		0.5 * float((rig["body_size_m"] as Vector3).y),
		float(rig["floor_top_y_m"]),
		0.0,
		measured_gravity_y,
		step_s,
		CAPTURE_FRAME_COUNT)
	_check(predicted_contact_frame >= 0,
		"semi-implicit drop oracle predicts a floor crossing inside the run")
	_check(
		first_contact_frame
			>= predicted_contact_frame - TIMING_EARLY_TOLERANCE_FRAMES
			and first_contact_frame
				<= predicted_contact_frame + TIMING_LATE_TOLERANCE_FRAMES,
		"first reported contact lies inside the preregistered discrete timing envelope "
			+ "(predicted frame %d, observed %d)"
				% [predicted_contact_frame, first_contact_frame])

	var all_precontact_empty := true
	for frame_id in first_contact_frame:
		all_precontact_empty = (
			(frames[frame_id].get("contacts", []) as Array).is_empty()
			and all_precontact_empty)
	_check(all_precontact_empty,
		"every frame before first impact reports zero contact")
	var near_ground_frame := _last_near_ground_airborne_frame(
		frames,
		first_contact_frame,
		0.5 * float((rig["body_size_m"] as Vector3).y),
		float(rig["floor_top_y_m"]))
	_check(near_ground_frame >= 0,
		"a near-ground but airborne frame exists before impact")
	if near_ground_frame >= 0:
		_check(
			(frames[near_ground_frame].get("contacts", []) as Array).is_empty(),
			"near-ground geometry alone does not invent contact")

	var contact_frame: Dictionary = frames[first_contact_frame]
	var contacts: Array = contact_frame["contacts"]
	var observed_body_matches := not contacts.is_empty()
	var floor_instance_matches := not contacts.is_empty()
	for raw_contact in contacts:
		var contact: Dictionary = raw_contact
		observed_body_matches = (
			String(contact.get("body_id", "")) == String(rig["body_id"])
			and observed_body_matches)
		floor_instance_matches = (
			int(contact.get("collider_instance_id", -1))
				== floor.get_instance_id()
			and floor_instance_matches)
	_check(observed_body_matches,
		"every first-impact normal belongs to the falling observed body")
	_check(floor_instance_matches,
		"every first-impact contact identifies the actual floor instance")

	var body_sample := _only_body(contact_frame)
	var body_transform := _value_to_transform(body_sample.get("transform", {}))
	var point_frames_valid := not contacts.is_empty()
	var normals_valid := not contacts.is_empty()
	var impulses_valid := not contacts.is_empty()
	for raw_contact in contacts:
		var contact: Dictionary = raw_contact
		var point_world := _value_to_vector(contact.get("point_world", []))
		var other_point_world := _value_to_vector(
			contact.get("other_point_world", []))
		var point_body_local := _value_to_vector(
			contact.get("point_body_local", []))
		var reconstructed_world := body_transform * point_body_local
		point_frames_valid = (
			point_world.is_finite()
			and other_point_world.is_finite()
			and point_body_local.is_finite()
			and absf(point_world.y - float(rig["floor_top_y_m"]))
				<= CONTACT_POINT_TOLERANCE_M
			and absf(other_point_world.y - float(rig["floor_top_y_m"]))
				<= CONTACT_POINT_TOLERANCE_M
			and absf(
				point_body_local.y
					+ 0.5 * float((rig["body_size_m"] as Vector3).y))
				<= CONTACT_POINT_TOLERANCE_M
			and reconstructed_world.distance_to(point_world)
				<= VECTOR_RECONSTRUCTION_TOLERANCE_M
			and point_frames_valid)

		var normal := _value_to_vector(contact.get("normal_world", []))
		normals_valid = (
			bool(contact.get("normal_available", false))
			and String(contact.get("normal_frame_source", ""))
				== "jolt_world_backend"
			and normal.is_finite()
			and absf(normal.length() - 1.0) <= NORMAL_LENGTH_TOLERANCE
			and normal.dot(Vector3.UP) >= NORMAL_UP_DOT_MINIMUM
			and normals_valid)

		var impulse := _value_to_vector(
			contact.get("impulse_world_ns", []))
		impulses_valid = (
			impulse.is_finite()
			and impulse.dot(normal) >= -NORMAL_IMPULSE_TOLERANCE_N_S
			and String(contact.get("impulse_quality", ""))
				== "jolt_predicted_estimate"
			and impulses_valid)
	_check(point_frames_valid,
		"world/body-local contact points reconstruct the box/floor geometry")
	_check(normals_valid,
		"the falling body's Jolt contact normal is finite, unit, and upward")
	_check(impulses_valid,
		"normal impulse is nonnegative and remains labeled a Jolt estimate")

	var peak_contact_count := 0
	for count_frame in frames:
		peak_contact_count = maxi(
			peak_contact_count,
			(count_frame.get("contacts", []) as Array).size())
	var contact_cap := int(rig["contact_cap_per_body"])
	_check(
		contact_cap > 0
			and int(body.max_contacts_reported) == contact_cap
			and peak_contact_count < contact_cap,
		"positive evidence remains strictly below the configured contact cap "
			+ "(peak %d, cap %d)" % [peak_contact_count, contact_cap])

	var all_frames_schema_valid := true
	for schema_frame in frames:
		var recorded_frame: Dictionary = schema_frame.duplicate(true)
		recorded_frame["schema"] = "sporespore.lab.frame.v1"
		recorded_frame["run_id"] = "br3a_box_drop_oracle"
		var validation: Dictionary = SchemaValidatorScript.validate_named(
			"frame_v1", recorded_frame)
		if not bool(validation.get("ok", false)):
			all_frames_schema_valid = false
			printerr(SchemaValidatorScript.format_errors(validation))
	_check(all_frames_schema_valid,
		"every raw positive-contact frame satisfies strict frame_v1 validation")

	world.queue_free()
	Engine.physics_ticks_per_second = original_ticks
	_finish()


static func _first_contact_frame(frames: Array[Dictionary]) -> int:
	for frame_id in frames.size():
		if not (frames[frame_id].get("contacts", []) as Array).is_empty():
			return frame_id
	return -1


static func _predicted_contact_frame(
		initial_center_y_m: float,
		body_half_height_m: float,
		floor_top_y_m: float,
		initial_velocity_y_m_s: float,
		gravity_y_m_s2: float,
		step_s: float,
		maximum_frames: int) -> int:
	for frame_id in maximum_frames:
		var step_number := frame_id + 1
		var predicted_center_y := (
			initial_center_y_m
			+ float(step_number) * initial_velocity_y_m_s * step_s
			+ 0.5 * gravity_y_m_s2 * step_s * step_s
				* float(step_number * (step_number + 1)))
		if predicted_center_y - body_half_height_m <= floor_top_y_m:
			return frame_id
	return -1


static func _last_near_ground_airborne_frame(
		frames: Array[Dictionary],
		first_contact_frame: int,
		body_half_height_m: float,
		floor_top_y_m: float) -> int:
	for frame_id in range(first_contact_frame - 1, -1, -1):
		var body := _only_body(frames[frame_id])
		var center := _value_to_vector(
			(body.get("transform", {}) as Dictionary).get("origin", []))
		var clearance := center.y - body_half_height_m - floor_top_y_m
		if (
				clearance > 0.0
				and clearance <= NEAR_GROUND_CLEARANCE_M
				and (frames[frame_id].get("contacts", []) as Array).is_empty()
		):
			return frame_id
	return -1


static func _only_body(frame: Dictionary) -> Dictionary:
	var bodies: Dictionary = frame.get("bodies", {})
	return bodies.values()[0] if bodies.size() == 1 else {}


static func _first_body_vector(frame: Dictionary, field: String) -> Vector3:
	return _value_to_vector(_only_body(frame).get(field, []))


static func _value_to_vector(value: Variant) -> Vector3:
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.INF


static func _value_to_transform(value: Variant) -> Transform3D:
	if not value is Dictionary:
		return Transform3D(Basis.IDENTITY, Vector3.INF)
	var transform_value: Dictionary = value
	var basis_value: Variant = transform_value.get("basis", [])
	if not basis_value is Array or basis_value.size() != 3:
		return Transform3D(Basis.IDENTITY, Vector3.INF)
	return Transform3D(
		Basis(
			_value_to_vector(basis_value[0]),
			_value_to_vector(basis_value[1]),
			_value_to_vector(basis_value[2])),
		_value_to_vector(transform_value.get("origin", [])))


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
