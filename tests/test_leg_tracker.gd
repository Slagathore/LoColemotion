extends SceneTree

## LegTracker pure math — the honest Jacobian-transpose leg controller. Checked against hand-computed
## values so the joint-torque law (task force → Jᵀ column) and the gravity-comp feed-forward (CTC
## G(q) term) are provably correct before they ever drive a real creature.

const LegTrackerScript := preload("res://scripts/sim/leg_tracker.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _run() -> void:
	print("=== LegTracker math tests ===")
	_test_task_force()
	_test_joint_task_torque()
	_test_gravity_torque()
	_test_subtree_com()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_task_force() -> void:
	print("- task force: PD spring at the foot, magnitude-capped")
	var f: Vector3 = LegTrackerScript.task_force(
			Vector3(1, 0, 0), Vector3.ZERO, Vector3.ZERO, 10.0, 0.0, 100.0)
	_check(f.is_equal_approx(Vector3(10, 0, 0)), "F = k·error when under the cap (10,0,0)")
	# Damping opposes foot velocity.
	var f2: Vector3 = LegTrackerScript.task_force(
			Vector3.ZERO, Vector3.ZERO, Vector3(0, 0, 2), 10.0, 3.0, 100.0)
	_check(f2.is_equal_approx(Vector3(0, 0, -6)), "damping opposes foot velocity (−D·v)")
	# Force magnitude clamps to max_force.
	var f3: Vector3 = LegTrackerScript.task_force(
			Vector3(100, 0, 0), Vector3.ZERO, Vector3.ZERO, 10.0, 0.0, 5.0)
	_check(absf(f3.length() - 5.0) < 1.0e-5 and f3.x > 0.0, "force magnitude clamps to max (5)")


func _test_joint_task_torque() -> void:
	print("- joint task torque = (axis × (p_foot − pivot)) · force")
	# Foot 1m below an X-axis hip; a forward (−Z) push needs +1 torque about +X (right-hand rule).
	var t: float = LegTrackerScript.joint_task_torque(
			Vector3(1, 0, 0), Vector3.ZERO, Vector3(0, -1, 0), Vector3(0, 0, -1))
	_check(absf(t - 1.0) < 1.0e-6, "forward push on a foot below the hip → +1 about +X")
	# A force pointing straight along the moment arm produces no torque.
	var t0: float = LegTrackerScript.joint_task_torque(
			Vector3(1, 0, 0), Vector3.ZERO, Vector3(0, -1, 0), Vector3(0, -1, 0))
	_check(absf(t0) < 1.0e-9, "force along the moment arm → zero torque")


func _test_gravity_torque() -> void:
	print("- gravity-comp: torque to HOLD the distal subtree at the current pose")
	# Mass 2 kg held 1 m forward (−Z) of an X-axis joint: holding torque = m·g·arm about +X.
	var t: float = LegTrackerScript.joint_gravity_torque(
			Vector3(1, 0, 0), Vector3.ZERO, Vector3(0, 0, -1), 2.0)
	_check(absf(t - 2.0 * 9.80665) < 1.0e-4, "hold 2 kg at 1 m offset → +m·g about +X")
	# A mass hanging straight below the joint needs no holding torque (arm ⟂ gravity is zero).
	var t0: float = LegTrackerScript.joint_gravity_torque(
			Vector3(1, 0, 0), Vector3.ZERO, Vector3(0, -1, 0), 2.0)
	_check(absf(t0) < 1.0e-6, "mass directly below the joint → zero gravity torque")


func _test_subtree_com() -> void:
	print("- subtree CoM: mass-weighted world centre of the distal bodies")
	# global_position is only meaningful inside the tree, so parent the bodies to root (as the real
	# controller does — its part bodies live in the sim world).
	var a := RigidBody3D.new()
	a.mass = 1.0
	root.add_child(a)
	a.global_position = Vector3.ZERO
	var b := RigidBody3D.new()
	b.mass = 3.0
	root.add_child(b)
	b.global_position = Vector3(4, 0, 0)
	var com: Vector3 = LegTrackerScript.subtree_com_world(
			[a, b], PackedInt32Array([0, 1]), Vector3.ZERO)
	_check(com.is_equal_approx(Vector3(3, 0, 0)), "CoM of {1 kg@0, 3 kg@4} = 3")
	# Empty/massless subtree falls back to the supplied pivot.
	var com0: Vector3 = LegTrackerScript.subtree_com_world(
			[], PackedInt32Array(), Vector3(7, 7, 7))
	_check(com0.is_equal_approx(Vector3(7, 7, 7)), "empty subtree → fallback pivot")
	a.free()
	b.free()
