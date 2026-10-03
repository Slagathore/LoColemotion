extends SceneTree

## BR2 pinned test: the labeled rotated box fixture, sampled through the
## complete sealed-frame chain (ObservedRigidBody -> SensorFrameBuilder).
##
## The fixture is a stationary box authored at a deliberately skew rotation
## with gravity disabled. What it proves:
##
## - ORIENTATION TRUTH: the sampled world transform reproduces the authored
##   rotation exactly and keeps reproducing it across ticks. Position truth
##   was BR1's L0.0; this is its rotational sibling, and it is the base
##   case every joint-angle reading in BR2 builds on (a joint angle is a
##   relationship between two of these transforms).
## - FRAME COHERENCE: every sealed frame carries one body, monotonically
##   advancing step/epoch identity, the integrate_callback phase, and
##   finite=true; the builder's own availability map marks the body as
##   measured and the whole-body aggregate as derived.
## - CENTER-OF-MASS ORACLE: the two independent engine expressions of the
##   center of mass (world com vs transform * local com) agree; their
##   disagreement channel com_frame_oracle_error_m stays at float noise.
## - THE v1 PIN HOLDS: the sealed frame_v1 whole_body aggregate still
##   reports angular momentum as null + BR1_INERTIA_CHANNEL_NOT_CERTIFIED.
##   BR2's rotational channels live in the separate whole_body_state_v2
##   aggregation until a frame_v2 experiment family versions the sealed
##   stream; this test guards that the BR2 work did NOT silently mutate the
##   certified v1 contract out from under the published BR1 bundles.

const ObservedRigidBodyScript := preload(
	"res://scripts/lab/mechanics/observed_rigid_body.gd")
const SensorFrameBuilderScript := preload(
	"res://scripts/lab/mechanics/sensor_frame_builder.gd")
const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== BR2 rotated-box sealed frame sampling ===")
	var authored_rotation := Quaternion(
		Vector3(2.0, -1.0, 3.0).normalized(), 0.85)
	var clock = CaptureClockScript.new()
	var world := Node3D.new()
	world.name = "Br2RotatedBoxWorld"
	var body = ObservedRigidBodyScript.new()
	body.body_id = &"rotated_box_0"
	body.part_index = 0
	body.capture_clock = clock
	body.observer_profile = {
		"profile_id": "br2_rotated_box_probe",
		"contacts_enabled": false,
		"contact_cap_per_body": 0,
		"channels": [],
	}
	body.mass = 2.0
	body.gravity_scale = 0.0
	body.can_sleep = false
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(0.25, 1.75, -0.5)
	body.quaternion = authored_rotation
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4, 0.6, 0.3)
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	root.add_child(world)
	Engine.physics_ticks_per_second = 60
	await process_frame
	await physics_frame

	var authored_basis := Basis(authored_rotation)
	var ticks := 30
	var frames: Array = []
	for tick in ticks:
		clock.open_epoch(tick, float(tick) / 60.0)
		await physics_frame
		clock.close_epoch()
		var builder = SensorFrameBuilderScript.new()
		builder.begin(
			tick, float(tick) / 60.0, &"integrate_callback", &"MEASURE", 0,
			[&"rotated_box_0"])
		builder.add_body_sample(body.latest_body_sample)
		builder.add_contacts(body.latest_contacts)
		frames.append(builder.seal())
	world.queue_free()
	await physics_frame

	var all_finite := true
	var identity_coherent := true
	var max_rotation_error := 0.0
	var max_com_oracle_error := 0.0
	var v1_pin_held := true
	var previous_step := -1
	var previous_epoch := -1
	for frame_value in frames:
		var frame: Dictionary = frame_value
		if not bool(frame["finite"]):
			all_finite = false
		var step := int(frame["physics_step_id"])
		var epoch := int(frame["capture_epoch"])
		if step <= previous_step or epoch <= previous_epoch \
				or String(frame["sample_phase"]) != "integrate_callback" \
				or (frame["bodies"] as Dictionary).size() != 1:
			identity_coherent = false
		previous_step = step
		previous_epoch = epoch
		var sample: Dictionary = (
			frame["bodies"] as Dictionary)["rotated_box_0"]
		var sampled_basis := _basis_from_rows(
			(sample["transform"] as Dictionary)["basis"])
		for column in 3:
			max_rotation_error = maxf(
				max_rotation_error,
				(sampled_basis[column]
					- authored_basis[column]).length())
		max_com_oracle_error = maxf(
			max_com_oracle_error,
			float(sample["com_frame_oracle_error_m"]))
		var whole_body: Dictionary = frame["whole_body"]
		var pin_entry: Dictionary = (
			whole_body["availability"] as Dictionary).get(
				"/angular_momentum_about_com_world_n_m_s", {})
		if (
			whole_body.get("angular_momentum_about_com_world_n_m_s") != null
			or String(pin_entry.get("status", "")) != "unavailable"
			or String(pin_entry.get("reason", ""))
				!= "BR1_INERTIA_CHANNEL_NOT_CERTIFIED"
		):
			v1_pin_held = false

	_check(frames.size() == ticks and all_finite,
		"all %d sealed frames are finite" % ticks)
	_check(identity_coherent,
		"step/epoch identity advances monotonically with one body per frame")
	_check(max_rotation_error < 1.0e-6,
		"authored skew rotation reproduced exactly (max basis err %.9f)"
			% max_rotation_error)
	_check(max_com_oracle_error < 1.0e-6,
		"center-of-mass frame oracle agrees (max err %.9f m)"
			% max_com_oracle_error)
	_check(v1_pin_held,
		"sealed frame_v1 still pins angular momentum unavailable (BR1 pin)")
	var availability: Dictionary = (frames[0] as Dictionary)["availability"]
	var fields: Dictionary = availability["fields"]
	_check(
		String((fields.get("body:rotated_box_0", {}) as Dictionary).get(
			"status", "")) == "measured"
		and String((fields.get("whole_body", {}) as Dictionary).get(
			"status", "")) == "derived",
		"builder availability map marks body measured, whole-body derived")
	_finish()


func _basis_from_rows(rows: Array) -> Basis:
	return Basis(
		_vector3(rows[0]), _vector3(rows[1]), _vector3(rows[2]))


func _vector3(value: Variant) -> Vector3:
	var raw: Array = value
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))


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
