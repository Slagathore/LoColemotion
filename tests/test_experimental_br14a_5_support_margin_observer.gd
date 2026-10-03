extends SceneTree

## Analytic commissioning for the read-only whole-system support-margin
## observer used to diagnose BR14A.5 candidate controllers.

const ObserverScript := preload("res://scripts/lab/mechanics/spatial_support_margin_observer.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR14A.5 support-margin observer ===")
	var fixture := Node3D.new()
	fixture.name = "SupportMarginObserverFixture"
	root.add_child(fixture)
	var body_a := _body(1.0, Vector3(-0.3, 0.2, 0.0))
	var body_b := _body(3.0, Vector3(0.1, 0.2, 0.0))
	var outside_body := _body(1.0, Vector3(2.0, 0.2, 0.0))
	fixture.add_child(body_a)
	fixture.add_child(body_b)
	fixture.add_child(outside_body)
	await process_frame
	var centered_bodies := {
		"a": body_a,
		"b": body_b,
	}
	var triangle: Array[Vector3] = [
		Vector3(-1.0, 0.0, -1.0),
		Vector3(1.0, 0.0, -1.0),
		Vector3(0.0, 0.0, 1.0),
	]
	var centered := ObserverScript.observe(centered_bodies, triangle)
	_check(bool(centered.get("ok", false)), "ordered nondegenerate support triangle observes")
	_check(
		(centered["center_of_mass_world_m"] as Vector3).is_equal_approx(Vector3(0.0, 0.2, 0.0)),
		"mass-weighted whole-system center of mass is exact"
	)
	_check(
		(
			bool(centered["inside_or_boundary"])
			and absf(float(centered["minimum_signed_margin_m"]) - (1.0 / sqrt(5.0))) <= 1.0e-6
		),
		"inside COM returns the exact minimum signed edge distance"
	)
	var reversed_triangle := triangle.duplicate()
	reversed_triangle.reverse()
	var reversed := ObserverScript.observe(centered_bodies, reversed_triangle)
	_check(
		(
			bool(reversed.get("ok", false))
			and (
				absf(
					(
						float(reversed["minimum_signed_margin_m"])
						- float(centered["minimum_signed_margin_m"])
					)
				)
				<= 1.0e-9
			)
		),
		"clockwise input is normalized without changing support margin"
	)
	var outside := ObserverScript.observe({"outside": outside_body}, triangle)
	_check(
		(
			bool(outside.get("ok", false))
			and not bool(outside["inside_or_boundary"])
			and float(outside["minimum_signed_margin_m"]) < 0.0
		),
		"outside COM returns a negative support margin"
	)
	var degenerate: Array[Vector3] = [
		Vector3.ZERO,
		Vector3.RIGHT,
		2.0 * Vector3.RIGHT,
	]
	_check(
		not bool(ObserverScript.observe(centered_bodies, degenerate).get("ok", false)),
		"degenerate support polygon fails closed"
	)
	var two_points: Array[Vector3] = [Vector3.ZERO, Vector3.RIGHT]
	_check(
		not bool(ObserverScript.observe(centered_bodies, two_points).get("ok", false)),
		"fewer than three support points fail closed"
	)
	_check(
		not bool(ObserverScript.observe({}, triangle).get("ok", false)),
		"empty body set fails closed"
	)
	_check(
		(
			not bool(centered["per_foot_measured_load_allocation_available"])
			and not bool(centered["contact_presence_is_bearing_measurement"])
			and not bool(centered["physics_state_modified"])
		),
		"geometric observer grants no load, bearing, or physics-write authority"
	)
	fixture.queue_free()
	await process_frame
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


static func _body(mass_kg: float, position: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.mass = mass_kg
	body.position = position
	body.freeze = true
	return body


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)
