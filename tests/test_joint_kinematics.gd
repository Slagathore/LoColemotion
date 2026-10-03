extends SceneTree

const JointKinematicsScript := preload("res://scripts/sim/joint_kinematics.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== JointKinematics tests ===")
	_test_known_angles()
	_test_parent_rotation_and_wrap()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _approx(a: float, b: float, tol: float) -> bool:
	return absf(wrapf(a - b, -PI, PI)) <= tol


func _test_known_angles() -> void:
	print("- reads signed hinge angles from basis pairs")
	var parent := Basis.IDENTITY
	var rest := Basis.IDENTITY
	for a in [-1.2, -0.3, 0.3, 1.2]:
		var child := parent * Basis(Vector3.RIGHT, a)
		var got := JointKinematicsScript.hinge_angle(parent, child, rest, Vector3.RIGHT)
		_check(_approx(got, a, 0.001), "angle %.2f round-trips" % a)


func _test_parent_rotation_and_wrap() -> void:
	print("- parent rotation and near-pi wrap stay signed")
	var parent := Basis(Vector3.UP, 0.7)
	var rest := Basis(Vector3.RIGHT, 0.2)
	var rel := rest * Basis(Vector3.RIGHT, PI - 0.02)
	var child := parent * rel
	var got := JointKinematicsScript.hinge_angle(parent, child, rest, Vector3.RIGHT)
	_check(_approx(got, PI - 0.02, 0.001), "near +PI angle survives parent rotation")
	rel = rest * Basis(Vector3.RIGHT, -PI + 0.02)
	child = parent * rel
	got = JointKinematicsScript.hinge_angle(parent, child, rest, Vector3.RIGHT)
	_check(_approx(got, -PI + 0.02, 0.001), "near -PI angle survives parent rotation")
