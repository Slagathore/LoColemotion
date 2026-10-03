extends SceneTree

## BR2 pinned test: the single-hinge fixture with a known axis, driven by a
## live Jolt joint, proving the sampled joint axis ROTATES WITH ITS PARENT.
##
## This is the direct executable form of the BR2 gate clauses "a rotated
## parent rotates sampled joint axis correctly" and "no controller reads
## stored construction-time world axes". The gait-era failure it guards
## against: cached world axes that were correct at build time and silently
## wrong the moment the body turned.
##
## Fixture: two boxes joined by a HingeJoint3D whose axis at construction
## points along world +X, with the hinge anchor placed AT the child's
## center of mass (so the spin's centripetal force, which acts through the
## anchor, exerts no moment about the child and the hinge angle stays at
## rest). Both bodies start with the same angular velocity about world +Y
## and gravity off, so the pair co-rotates as a rigid assembly, carrying
## the hinge axis around the Y axis.
##
## Per-tick assertions through LabJointState (which recomputes everything
## from live transforms and the sealed local-frame binding):
## - the sample stays valid: parent-side and child-side axis recomputations
##   agree, and the two world anchors coincide within the authored solver
##   tolerance, for every tick;
## - the live world axis ends the run rotated away from its
##   construction-time value by exactly the parent's rotation angle, so any
##   consumer still holding the construction axis would now be provably
##   wrong by that same angle;
## - the hinge angle stays at rest and its unwrapped stream stays
##   continuous (no torque about the hinge axis by construction);
## - the swing residual stays small, witnessing that the live Jolt joint
##   actually behaves as the hinge the binding declares.

const ObservedRigidBodyScript := preload(
	"res://scripts/lab/mechanics/observed_rigid_body.gd")
const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const JointBindingScript := preload(
	"res://scripts/lab/mechanics/joint_binding.gd")
const JointStateScript := preload(
	"res://scripts/lab/mechanics/joint_state.gd")
const MechanicsBodySampleScript := preload(
	"res://scripts/lab/mechanics/mechanics_body_sample.gd")
const JointAngleStreamScript := preload(
	"res://scripts/lab/mechanics/joint_angle_stream.gd")

const SPIN_RAD_S := 0.9
const TICKS := 60

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== BR2 live hinge axis rotates with parent ===")
	var clock = CaptureClockScript.new()
	var profile := {
		"profile_id": "br2_hinge_probe",
		"contacts_enabled": false,
		"contact_cap_per_body": 0,
		"channels": [],
	}
	var world := Node3D.new()
	world.name = "Br2HingeWorld"

	var parent_body = _observed_body(
		&"hinge_parent", clock, profile, Vector3(0.0, 2.0, 0.0))
	var child_body = _observed_body(
		&"hinge_child", clock, profile, Vector3(0.5, 2.0, 0.0))
	# Rigid co-rotation start: both bodies share the spin about world +Y so
	# the joint begins load-free and the assembly turns as one piece.
	parent_body.angular_velocity = Vector3(0.0, SPIN_RAD_S, 0.0)
	child_body.angular_velocity = Vector3(0.0, SPIN_RAD_S, 0.0)
	# The child orbits the parent's axis, so its linear velocity at start is
	# omega x r for its offset r = (0.5, 0, 0).
	child_body.linear_velocity = Vector3(
		0.0, SPIN_RAD_S, 0.0).cross(Vector3(0.5, 0.0, 0.0))
	world.add_child(parent_body)
	world.add_child(child_body)

	# HingeJoint3D frees rotation about the JOINT node's local Z axis (the
	# frozen-legs bug of the gait era came from forgetting exactly this), so
	# the joint basis maps +Z onto the desired world +X axis. The anchor
	# sits at the child's center, on the line of the axis.
	var joint := HingeJoint3D.new()
	joint.transform = Transform3D(
		Basis(Quaternion(Vector3.UP, PI / 2.0)), Vector3(0.5, 2.0, 0.0))
	world.add_child(joint)
	root.add_child(world)
	joint.node_a = joint.get_path_to(parent_body)
	joint.node_b = joint.get_path_to(child_body)

	# The sealed binding authors ONLY local-frame quantities. At build time
	# the parent is unrotated, so the world +X hinge axis is parent-local
	# (1,0,0); the child shares the orientation, so child-local matches.
	# The anchor is the child's center: (0.5, 0, 0) in the parent's frame,
	# the origin in the child's frame. Agreement tolerances are authored for
	# a live float32 solver holding a spinning pair, not for exact algebra.
	var built: Dictionary = JointBindingScript.build({
		"joint_id": "br2_live_hinge",
		"parent_body_id": "hinge_parent",
		"child_body_id": "hinge_child",
		"axis_parent_local": Vector3(1, 0, 0),
		"axis_child_local": Vector3(1, 0, 0),
		"anchor_parent_local": Vector3(0.5, 0.0, 0.0),
		"anchor_child_local": Vector3.ZERO,
		"rest_child_rotation_parent_local": Quaternion.IDENTITY,
		"anchor_agreement_tolerance_m": 5.0e-3,
		"axis_agreement_tolerance_rad": 2.0e-2,
		"swing_tolerance_rad": 2.0e-2,
		"local_joint_scale_m": 1.0,
		"local_joint_scale_basis": "joint_fixture_extent_min_v1",
		"morphology_config_digest_sha256":
			"sha256:%s" % "br2-live-hinge-fixture-v1".sha256_text(),
	})
	assert(bool(built["ok"]), "live hinge binding must build")
	var binding: Dictionary = built["binding"]

	Engine.physics_ticks_per_second = 60
	await process_frame
	await physics_frame

	var construction_axis := Vector3(1.0, 0.0, 0.0)
	var every_tick_valid := true
	var first_invalid_reasons: Array = []
	var max_anchor_error := 0.0
	var max_axis_disagreement := 0.0
	var max_swing := 0.0
	var max_angle := 0.0
	var first_axis := construction_axis
	var final_axis := construction_axis
	var final_direct_parent_axis := construction_axis
	var previous_state: Dictionary = {}
	var angle_stream = JointAngleStreamScript.new()
	var measured_ticks := 0
	for tick in TICKS:
		clock.open_epoch(tick, float(tick) / 60.0)
		await physics_frame
		clock.close_epoch()
		var parent_projection: Dictionary = MechanicsBodySampleScript.project(
			parent_body.latest_body_sample,
			"br2-live-hinge-run",
			"br2-live-hinge-capture")
		var child_projection: Dictionary = MechanicsBodySampleScript.project(
			child_body.latest_body_sample,
			"br2-live-hinge-run",
			"br2-live-hinge-capture")
		assert(bool(parent_projection["ok"])
			and bool(child_projection["ok"]),
			"live body samples must project into the BR2 mechanics contract")
		var parent_sample: Dictionary = parent_projection["sample"]
		var child_sample: Dictionary = child_projection["sample"]
		var initialization_witness: Dictionary = {}
		if previous_state.is_empty():
			initialization_witness = {
				"schema_version":
					"joint_unwrap_initialization_witness_v1",
				"unwrap_segment_id": 1,
				"physics_step_id": int(parent_sample["physics_step_id"]),
				"capture_epoch": int(parent_sample["capture_epoch"]),
				"sample_phase": String(parent_sample["sample_phase"]),
				"joint_id": String(binding["joint_id"]),
				"binding_digest_sha256":
					String(binding["binding_digest_sha256"]),
				"run_id": "br2-live-hinge-run",
				"capture_stream_id": "br2-live-hinge-capture",
				"authored_turn_index": 0,
				"fixture_configuration_digest_sha256":
					"sha256:%s" % "br2-live-hinge-fixture-v1".sha256_text(),
				"expected_wrapped_angle_rad": 0.0,
				"maximum_pose_residual_rad": 5.0e-2,
				"initialization_reason": "fixture_scaffold",
			}
		var operation: Dictionary = (
			angle_stream.start_segment(
				binding,
				parent_sample,
				child_sample,
				initialization_witness)
			if previous_state.is_empty()
			else angle_stream.advance(
				binding, parent_sample, child_sample))
		var state: Dictionary = (
			operation["state"] if operation["state"] is Dictionary else {})
		if not bool(operation["ok"]) or not bool(state.get("complete", false)):
			every_tick_valid = false
			first_invalid_reasons = (
				state.get("invalid_reasons", [])
				if not state.is_empty()
				else [String(operation["code"])])
			break
		max_anchor_error = maxf(
			max_anchor_error, float(state["anchor_agreement_error_m"]))
		max_axis_disagreement = maxf(
			max_axis_disagreement,
			float(state["axis_agreement_error_rad"]))
		max_swing = maxf(max_swing, absf(float(state["swing_residual_rad"])))
		max_angle = maxf(
			max_angle, absf(float(state["unwrapped_angle_rad"])))
		final_axis = _vector3(state["current_axis_world"])
		var parent_transform := _transform3(parent_sample["transform"])
		final_direct_parent_axis = (
			parent_transform.basis * construction_axis).normalized()
		if measured_ticks == 0:
			first_axis = final_axis
		previous_state = state
		measured_ticks += 1
	world.queue_free()
	await physics_frame

	_check(every_tick_valid,
		"joint sample valid on all %d ticks%s" % [
			measured_ticks,
			"" if every_tick_valid else " (first invalid: %s)"
				% str(first_invalid_reasons)])
	_check(max_anchor_error < 5.0e-3,
		"live solver held hinge anchors together (max %.6f m)"
			% max_anchor_error)
	_check(max_axis_disagreement < 2.0e-2,
		"parent-side and child-side axis recomputations agree (max %.6f rad)"
			% max_axis_disagreement)
	_check(max_swing < 2.0e-2,
		"pair behaved as a hinge: swing residual max %.6f rad" % max_swing)
	_check(max_angle < 5.0e-2,
		"torque-free hinge stayed at rest (max |angle| %.6f rad)"
			% max_angle)

	# Setup frames legitimately rotate the body before tick 0, so compare the
	# sampled interval rather than pretending process-start time is evidence.
	# Across 59 captured intervals, omega predicts the relative axis motion.
	# Independently decoding the final engine transform must name the same axis.
	var expected_sampled_rotation := \
		SPIN_RAD_S * float(maxi(measured_ticks - 1, 0)) / 60.0
	var observed_sampled_rotation := first_axis.angle_to(final_axis)
	_check(absf(observed_sampled_rotation - expected_sampled_rotation) < 3.0e-2
		and final_axis.distance_to(final_direct_parent_axis) < 1.0e-5
		and construction_axis.angle_to(final_axis) > 0.5,
		"live axis advanced %.3f rad across sampled ticks (expected %.3f)"
			% [observed_sampled_rotation, expected_sampled_rotation]
			+ " and matches the final engine transform; cached axis is wrong")
	_finish()


func _observed_body(
		body_id: StringName,
		clock,
		profile: Dictionary,
		position: Vector3):
	var body = ObservedRigidBodyScript.new()
	body.body_id = body_id
	body.part_index = 0
	body.capture_clock = clock
	body.observer_profile = profile.duplicate(true)
	body.mass = 1.5
	body.gravity_scale = 0.0
	body.can_sleep = false
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.25, 0.25, 0.25)
	collision.shape = shape
	body.add_child(collision)
	return body


func _vector3(value: Variant) -> Vector3:
	var raw: Array = value
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))


func _transform3(value: Variant) -> Transform3D:
	var raw: Dictionary = value
	var rows: Array = raw["basis"]
	return Transform3D(
		Basis(_vector3(rows[0]), _vector3(rows[1]), _vector3(rows[2])),
		_vector3(raw["origin"]))


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
