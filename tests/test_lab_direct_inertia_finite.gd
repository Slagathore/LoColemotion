extends SceneTree

## BR2 pinned test: the collider-inertia comparison fixture.
##
## The BR2 gate requires that the engine's inverse inertia tensor is
## RECORDED alongside an analytic estimate, and that the recorded channel is
## trustworthy: finite, symmetric, and agreeing with the analytic solid-body
## tensor for known primitive shapes, including when the body is authored at
## a non-identity rotation (the world tensor must be R * I_local^-1 * R^T,
## not the local tensor copied through).
##
## Why this matters for everything above BR2: the gait era tuned torque caps
## against subtree inertia ESTIMATES that were never checked against the
## engine (the memory of "tau_cap ~89 N*m no matter the muscle" came from
## exactly such an estimate). Every later actuator envelope (BR4) divides by
## these tensors, so a silent disagreement here would scale every torque
## computation after it.
##
## Two shapes are compared:
## - solid box 0.4 x 0.6 x 0.3 at mass 2:
##       I = m/12 * diag(h^2+d^2, w^2+d^2, w^2+h^2)
##         = diag(0.075, 0.041666667, 0.086666667) kg m^2
## - solid sphere radius 0.25 at mass 3:
##       I = 2/5 * m * r^2 * identity = 0.075 * identity kg m^2
## The box is authored ROTATED so the world-frame comparison exercises the
## similarity transform, not just a diagonal copy.

const ObservedRigidBodyScript := preload(
	"res://scripts/lab/mechanics/observed_rigid_body.gd")
const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")

# The historical assertion allowed 1e-3 even though the commissioned Jolt
# fixtures were already within roughly 2e-6. A 1e-5 preregistered envelope
# still leaves several float32 rounding widths without allowing a 0.1% tensor
# scale error to become the basis of every later torque calculation.
const ANALYTIC_RELATIVE_TOLERANCE := 1.0e-5

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== BR2 direct inertia channel vs analytic colliders ===")
	# Authored rotation for the box: 0.6 rad about a skew axis, so no world
	# axis lines up with a principal axis and every off-diagonal term of the
	# world tensor is exercised.
	var box_rotation := Quaternion(Vector3(1.0, 2.0, 0.5).normalized(), 0.6)
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.4, 0.6, 0.3)
	var box_inertia_local := Basis(
		Vector3(0.075, 0.0, 0.0),
		Vector3(0.0, 2.0 / 12.0 * (0.16 + 0.09), 0.0),
		Vector3(0.0, 0.0, 2.0 / 12.0 * (0.16 + 0.36)))
	await _shape_case(
		"rotated_box", box_shape, 2.0, box_rotation, box_inertia_local)

	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.25
	var sphere_inertia := 0.4 * 3.0 * 0.25 * 0.25
	await _shape_case(
		"sphere", sphere_shape, 3.0, Quaternion.IDENTITY,
		Basis.IDENTITY.scaled(
			Vector3(sphere_inertia, sphere_inertia, sphere_inertia)))
	_finish()


func _shape_case(
		case_name: String,
		shape: Shape3D,
		mass: float,
		rotation: Quaternion,
		analytic_inertia_local: Basis) -> void:
	var clock = CaptureClockScript.new()
	var world := Node3D.new()
	world.name = "Br2InertiaWorld_%s" % case_name
	var body = ObservedRigidBodyScript.new()
	body.body_id = &"inertia_probe"
	body.part_index = 0
	body.capture_clock = clock
	body.observer_profile = {
		"profile_id": "br2_inertia_probe",
		"contacts_enabled": false,
		"contact_cap_per_body": 0,
		"channels": [],
	}
	body.mass = mass
	body.gravity_scale = 0.0
	body.can_sleep = false
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(0.0, 2.0, 0.0)
	body.quaternion = rotation
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	root.add_child(world)
	Engine.physics_ticks_per_second = 60
	await process_frame
	await physics_frame

	var sampled := Basis.IDENTITY
	var sample_ok := false
	for tick in 3:
		clock.open_epoch(tick, float(tick) / 60.0)
		await physics_frame
		clock.close_epoch()
		var sample: Dictionary = body.latest_body_sample
		if sample.is_empty() or not bool(sample.get("finite", false)):
			sample_ok = false
			break
		sampled = _basis_from_value(sample["inverse_inertia_tensor_world"])
		sample_ok = true
	world.queue_free()
	await physics_frame

	_check(sample_ok, "%s: inverse inertia sampled finite on every tick"
		% case_name)
	if not sample_ok:
		return

	# Symmetry: an inertia tensor (and its inverse) is symmetric by
	# definition; a structural asymmetry would mean the channel is not a
	# tensor at all. The bound is calibrated to the backend's precision:
	# Jolt computes in float32, so a rotated tensor's off-diagonal pairs
	# differ by rounding at roughly 1e-7 relative to entry magnitude
	# (measured 2.4e-7 absolute on entries of magnitude ~24). The sphere's
	# untouched diagonal tensor is exactly symmetric.
	var asymmetry := maxf(
		absf(sampled.x.y - sampled.y.x),
		maxf(absf(sampled.x.z - sampled.z.x),
			absf(sampled.y.z - sampled.z.y)))
	var entry_scale := maxf(_basis_magnitude(sampled), 1.0)
	_check(asymmetry / entry_scale < 1.0e-6,
		"%s: sampled inverse tensor symmetric to float32 rounding (rel %.12f)"
			% [case_name, asymmetry / entry_scale])

	# World-frame comparison: the engine channel must equal
	# R * I_local^-1 * R^T for the analytic local tensor and the authored
	# rotation. This is the "recorded alongside an analytic estimate" gate
	# clause with the estimate actually checked, not just written down.
	var rotation_basis := Basis(rotation)
	var analytic_inverse_world := (
		rotation_basis * analytic_inertia_local.inverse()
		* rotation_basis.transposed())
	var worst_relative := 0.0
	for row in 3:
		for column in 3:
			var analytic_entry := analytic_inverse_world[row][column]
			var sampled_entry := sampled[row][column]
			var scale := maxf(absf(analytic_entry), 1.0)
			worst_relative = maxf(
				worst_relative,
				absf(sampled_entry - analytic_entry) / scale)
	_check(worst_relative < ANALYTIC_RELATIVE_TOLERANCE,
		"%s: engine inverse inertia matches analytic (rel %.9f < %.9f)"
			% [case_name, worst_relative, ANALYTIC_RELATIVE_TOLERANCE])


func _basis_from_value(value: Variant) -> Basis:
	# Godot Basis.x/y/z are columns (transformed local axes), despite the
	# common temptation to call these serialized vectors rows.
	var columns: Dictionary = value
	return Basis(
		_vector3(columns["x"]),
		_vector3(columns["y"]),
		_vector3(columns["z"]))


func _basis_magnitude(value: Basis) -> float:
	return maxf(
		value.x.length(), maxf(value.y.length(), value.z.length()))


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
