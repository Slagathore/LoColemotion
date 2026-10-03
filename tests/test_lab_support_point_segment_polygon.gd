extends SceneTree

const SupportGeometryScript := preload(
	"res://scripts/lab/mechanics/support_geometry.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== BR3A point/segment/capsule/polygon support geometry ===")
	var point_inside: Dictionary = _analyze(
		[Vector3.ZERO], Vector3.ZERO)
	var point_outside: Dictionary = _analyze(
		[Vector3.ZERO], Vector3(0.1, 0.0, 0.0))
	_check(String(point_inside["support_kind"]) == "POINT"
		and int(point_inside["support_dimension"]) == 0
		and bool(point_inside["query_inside_support"])
		and not bool(point_outside["query_inside_support"]),
		"single contact remains zero-dimensional point support")

	var line_points := [
		Vector3(-1.0, 0.0, 0.0),
		Vector3.ZERO,
		Vector3(1.0, 0.0, 0.0),
	]
	var segment_inside: Dictionary = _analyze(
		line_points, Vector3(0.2, 0.0, 0.0))
	var segment_past_end: Dictionary = _analyze(
		line_points, Vector3(1.2, 0.0, 0.0))
	_check(String(segment_inside["support_kind"]) == "SEGMENT"
		and int(segment_inside["hull_point_count"]) == 2
		and bool(segment_inside["query_inside_support"])
		and not bool(segment_past_end["query_inside_support"]),
		"collinear contacts preserve segment endpoints and finite extent")
	var capsule: Dictionary = SupportGeometryScript.analyze(
		line_points,
		Vector3.ZERO,
		Vector3.UP,
		Vector3(0.0, 0.0, 0.15),
		0.2)
	_check(String(capsule["support_kind"]) == "CAPSULE"
		and bool(capsule["query_inside_support"])
		and absf(float(capsule["signed_margin_m"]) - 0.05) < 1.0e-6,
		"authored limb radius upgrades only a segment into a bounded capsule")

	var square := [
		Vector3(-1.0, 0.0, -1.0),
		Vector3(1.0, 0.0, 1.0),
		Vector3(0.0, 0.0, 0.0),
		Vector3(1.0, 0.0, -1.0),
		Vector3(-1.0, 0.0, 1.0),
		Vector3(-1.0, 0.0, -1.0),
	]
	var polygon_inside: Dictionary = _analyze(square, Vector3.ZERO)
	var polygon_outside: Dictionary = _analyze(
		square, Vector3(1.1, 0.0, 0.0))
	_check(String(polygon_inside["support_kind"]) == "POLYGON"
		and int(polygon_inside["hull_point_count"]) == 4
		and absf(float(polygon_inside["support_area_m2"]) - 4.0)
			< 1.0e-6
		and bool(polygon_inside["query_inside_support"])
		and float(polygon_inside["signed_margin_m"]) > 0.99,
		"duplicates and interior points reduce to the four-corner support hull")
	_check(not bool(polygon_outside["query_inside_support"])
		and float(polygon_outside["signed_margin_m"]) < -0.09
		and float(polygon_outside["distance_to_support_m"]) > 0.09,
		"outside polygon query reports negative edge margin and distance")

	var tilted_normal := Vector3(0.0, 1.0, 1.0).normalized()
	var tilted_u := tilted_normal.cross(Vector3.RIGHT).normalized()
	var tilted_v := tilted_normal.cross(tilted_u).normalized()
	var tilted_origin := Vector3(3.0, -2.0, 4.0)
	var tilted_points := [
		tilted_origin - tilted_u - tilted_v,
		tilted_origin + tilted_u - tilted_v,
		tilted_origin + tilted_u + tilted_v,
		tilted_origin - tilted_u + tilted_v,
	]
	var tilted: Dictionary = SupportGeometryScript.analyze(
		tilted_points,
		tilted_origin,
		tilted_normal,
		tilted_origin + 2.0 * tilted_normal)
	_check(bool(tilted["finite"])
		and bool(tilted["query_inside_support"])
		and absf(float(tilted["query_plane_height_m"]) - 2.0) < 1.0e-6
		and (tilted["query_projection_world"] as Vector3).distance_to(
			tilted_origin) < 1.0e-6,
		"arbitrary support plane evaluates the query's plane projection")

	var out_of_plane := square.duplicate()
	out_of_plane.append(Vector3(0.0, 0.01, 0.0))
	var rejected: Dictionary = _analyze(out_of_plane, Vector3.ZERO)
	_check(not bool(rejected["finite"])
		and (rejected["invalid_reasons"] as Array).has(
			"SUPPORT_POINT_OUT_OF_PLANE:6"),
		"noncoplanar points cannot be smuggled into one support polygon")

	var cop: Dictionary = SupportGeometryScript.center_of_pressure([
		{"point_world": Vector3(-1, 0, 0), "normal_weight": 1.0},
		{"point_world": Vector3(1, 0, 0), "normal_weight": 3.0},
	])
	_check(bool(cop["finite"])
		and (cop["center_of_pressure_world"] as Vector3).distance_to(
			Vector3(0.5, 0, 0)) < 1.0e-9,
		"center of pressure uses explicit normal weights (1:3 gives x=0.5)")
	var zero_weight: Dictionary = SupportGeometryScript.center_of_pressure([
		{"point_world": Vector3.ZERO, "normal_weight": 0.0},
	])
	_check(not bool(zero_weight["finite"])
		and zero_weight["center_of_pressure_world"] == null,
		"zero total load never fabricates a center of pressure")
	_finish()


func _analyze(points: Array, query: Vector3) -> Dictionary:
	return SupportGeometryScript.analyze(
		points, Vector3.ZERO, Vector3.UP, query)


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
