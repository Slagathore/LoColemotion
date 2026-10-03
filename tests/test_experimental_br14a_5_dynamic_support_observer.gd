extends SceneTree

## Analytic commissioning for the read-only dynamic support-state observer
## used by the next BR14A.5 controller family.

const ObserverScript := preload("res://scripts/lab/mechanics/spatial_dynamic_support_observer.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR14A.5 dynamic support observer ===")
	var fixture := Node3D.new()
	fixture.name = "DynamicSupportObserverFixture"
	root.add_child(fixture)
	var body_a := _body(1.0, Vector3(-0.3, 0.4, 0.0), Vector3(-0.1, 0.0, 0.0))
	var body_b := _body(3.0, Vector3(0.1, 0.4, 0.0), Vector3(0.3, 0.0, 0.0))
	fixture.add_child(body_a)
	fixture.add_child(body_b)
	await process_frame
	var bodies := {"a": body_a, "b": body_b}
	var triangle: Array[Vector3] = [
		Vector3(-1.0, 0.0, -1.0),
		Vector3(1.0, 0.0, -1.0),
		Vector3(0.0, 0.0, 1.0),
	]
	var observed := ObserverScript.observe(bodies, triangle, 9.8)
	_check(bool(observed.get("ok", false)), "valid dynamic support fixture observes")
	_check(
		(observed["center_of_mass_world_m"] as Vector3).is_equal_approx(Vector3(0.0, 0.4, 0.0)),
		"mass-weighted COM position is exact"
	)
	_check(
		(observed["center_of_mass_velocity_world_m_s"] as Vector3).is_equal_approx(
			Vector3(0.2, 0.0, 0.0)
		),
		"mass-weighted COM velocity is exact"
	)
	var expected_frequency := sqrt(9.8 / 0.4)
	var expected_capture := Vector3(0.2 / expected_frequency, 0.4, 0.0)
	_check(
		(
			(observed["linearized_capture_point_world_m"] as Vector3).distance_to(expected_capture)
			<= 1.0e-6
		),
		"linearized horizontal capture projection is exact"
	)
	_check(
		(
			(
				float(observed["linearized_capture_margin_m"])
				< float(observed["center_of_mass_margin_m"])
			)
			and (
				float(observed["minimum_dynamic_support_margin_m"])
				== float(observed["linearized_capture_margin_m"])
			)
		),
		"outward COM velocity reduces the reported dynamic support margin"
	)
	_check(
		(observed["support_centroid_world_m"] as Vector3).is_equal_approx(
			Vector3(0.0, 0.0, -1.0 / 3.0)
		),
		"area-weighted support centroid is exact"
	)
	var reversed_triangle := triangle.duplicate()
	reversed_triangle.reverse()
	var reversed := ObserverScript.observe(bodies, reversed_triangle, 9.8)
	_check(
		(
			bool(reversed.get("ok", false))
			and (
				absf(
					(
						float(reversed["linearized_capture_margin_m"])
						- float(observed["linearized_capture_margin_m"])
					)
				)
				<= 1.0e-9
			)
		),
		"clockwise input is normalized without changing dynamic margin"
	)
	var segment: Array[Vector3] = [
		Vector3(-1.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
	]
	var segment_observed := ObserverScript.observe(bodies, segment, 9.8)
	_check(
		(
			bool(segment_observed.get("ok", false))
			and int(segment_observed.get("support_geometry_dimension", -1)) == 1
			and String(segment_observed.get("support_geometry_kind", "")) == "SEGMENT"
			and not bool(segment_observed.get("support_polygon_available", true))
			and is_zero_approx(float(segment_observed["center_of_mass_margin_m"]))
		),
		"two contacts retain an explicit zero-area support segment instead of dropping the tick"
	)
	var point: Array[Vector3] = [Vector3.ZERO]
	var point_observed := ObserverScript.observe(bodies, point, 9.8)
	_check(
		(
			bool(point_observed.get("ok", false))
			and int(point_observed.get("support_geometry_dimension", -1)) == 0
			and String(point_observed.get("support_geometry_kind", "")) == "POINT"
			and not bool(point_observed.get("support_polygon_available", true))
		),
		"one contact retains an explicit zero-area support point instead of inventing a polygon"
	)
	var concave: Array[Vector3] = [
		Vector3(-1.0, 0.0, -1.0),
		Vector3(1.0, 0.0, -1.0),
		Vector3(0.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 1.0),
		Vector3(-1.0, 0.0, 1.0),
	]
	_check(
		not bool(ObserverScript.observe(bodies, concave, 9.8).get("ok", false)),
		"nonconvex support polygon fails closed"
	)
	_check(
		not bool(ObserverScript.observe(bodies, triangle, 0.0).get("ok", false)),
		"nonpositive gravity fails closed"
	)
	var below_support := _body(1.0, Vector3.ZERO, Vector3.ZERO)
	fixture.add_child(below_support)
	var raised_triangle: Array[Vector3] = [
		Vector3(-1.0, 0.1, -1.0),
		Vector3(1.0, 0.1, -1.0),
		Vector3(0.0, 0.1, 1.0),
	]
	_check(
		not bool(
			ObserverScript.observe({"below": below_support}, raised_triangle, 9.8).get("ok", false)
		),
		"COM at or below the support plane fails closed"
	)
	_check(
		(
			bool(observed["linearized_capture_model_only"])
			and not bool(observed["articulated_capture_guarantee_available"])
			and not bool(observed["per_foot_measured_load_allocation_available"])
			and not bool(observed["contact_presence_is_bearing_measurement"])
			and not bool(observed["physics_state_modified"])
		),
		"observer grants no articulated guarantee, load, bearing, or write authority"
	)
	fixture.queue_free()
	await process_frame
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


static func _body(mass_kg: float, position: Vector3, velocity: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.mass = mass_kg
	body.position = position
	body.linear_velocity = velocity
	body.freeze = true
	return body


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)
