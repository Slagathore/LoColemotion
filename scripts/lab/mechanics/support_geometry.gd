class_name LabSupportGeometry
extends RefCounted

## BR3A support-plane geometry for arbitrary morphology.
##
## A confirmed support set can be zero-dimensional (point), one-dimensional
## (segment/capsule), or two-dimensional (convex polygon).  The implementation
## projects onto an explicit plane, deduplicates points, builds a deterministic
## convex hull, and evaluates the projected query point. It never upgrades a
## point or line into a polygon and never treats out-of-plane data as coplanar.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA_VERSION := "support_geometry_v1"
const NORMAL_EPSILON := 1.0e-12


static func analyze(
		points_world: Array,
		plane_origin_world: Vector3,
		plane_normal_world: Vector3,
		query_world: Vector3,
		segment_radius_m: float = 0.0,
		duplicate_tolerance_m: float = 1.0e-6,
		plane_tolerance_m: float = 1.0e-4) -> Dictionary:
	var reasons: Array[String] = []
	if points_world.is_empty():
		reasons.append("NO_SUPPORT_POINTS")
	if not plane_origin_world.is_finite() \
			or not plane_normal_world.is_finite() \
			or plane_normal_world.length_squared() <= NORMAL_EPSILON \
			or not query_world.is_finite():
		reasons.append("SUPPORT_PLANE_OR_QUERY_INVALID")
	if not is_finite(segment_radius_m) or segment_radius_m < 0.0:
		reasons.append("SEGMENT_RADIUS_INVALID")
	if not is_finite(duplicate_tolerance_m) \
			or duplicate_tolerance_m <= 0.0 \
			or not is_finite(plane_tolerance_m) \
			or plane_tolerance_m <= 0.0:
		reasons.append("SUPPORT_GEOMETRY_TOLERANCE_INVALID")
	if not reasons.is_empty():
		return _invalid(reasons)

	var normal := plane_normal_world.normalized()
	var axes := _plane_axes(normal)
	var axis_u: Vector3 = axes[0]
	var axis_v: Vector3 = axes[1]
	var points_2d: Array[Vector2] = []
	var maximum_plane_error_m := 0.0
	for index in points_world.size():
		var point_value: Variant = points_world[index]
		if not point_value is Vector3 \
				or not (point_value as Vector3).is_finite():
			reasons.append("SUPPORT_POINT_INVALID:%d" % index)
			continue
		var point: Vector3 = point_value
		var offset := point - plane_origin_world
		var plane_error := absf(offset.dot(normal))
		maximum_plane_error_m = maxf(
			maximum_plane_error_m, plane_error)
		if plane_error > plane_tolerance_m:
			reasons.append("SUPPORT_POINT_OUT_OF_PLANE:%d" % index)
		var projected := Vector2(offset.dot(axis_u), offset.dot(axis_v))
		if not _contains_near(
				points_2d, projected, duplicate_tolerance_m):
			points_2d.append(projected)
	if not reasons.is_empty():
		return _invalid(reasons)
	if points_2d.is_empty():
		return _invalid(["NO_UNIQUE_SUPPORT_POINTS"])

	var query_offset := query_world - plane_origin_world
	var query_plane_height_m := query_offset.dot(normal)
	var query_2d := Vector2(
		query_offset.dot(axis_u), query_offset.dot(axis_v))
	var hull := _convex_hull(points_2d, duplicate_tolerance_m)
	var classification := _classify_and_evaluate(
		hull,
		query_2d,
		segment_radius_m,
		duplicate_tolerance_m)
	var hull_world: Array = []
	for point_2d in hull:
		hull_world.append(
			plane_origin_world
			+ axis_u * point_2d.x
			+ axis_v * point_2d.y)
	var query_projection_world := (
		plane_origin_world
		+ axis_u * query_2d.x
		+ axis_v * query_2d.y)
	return FrozenValueScript.snapshot({
		"schema_version": SCHEMA_VERSION,
		"finite": true,
		"invalid_reasons": [],
		"support_kind": classification["support_kind"],
		"support_dimension": classification["support_dimension"],
		"unique_point_count": points_2d.size(),
		"hull_point_count": hull.size(),
		"hull_points_world": hull_world,
		"plane_origin_world": plane_origin_world,
		"plane_normal_world": normal,
		"plane_axis_u_world": axis_u,
		"plane_axis_v_world": axis_v,
		"maximum_input_plane_error_m": maximum_plane_error_m,
		"query_world": query_world,
		"query_projection_world": query_projection_world,
		"query_plane_height_m": query_plane_height_m,
		"query_inside_support": classification["inside"],
		"signed_margin_m": classification["signed_margin_m"],
		"distance_to_support_m": classification["distance_to_support_m"],
		"support_area_m2": classification["support_area_m2"],
		"support_length_m": classification["support_length_m"],
		"segment_radius_m": segment_radius_m,
		"degenerate_geometry_preserved": hull.size() < 3,
	})


static func center_of_pressure(samples: Array) -> Dictionary:
	var reasons: Array[String] = []
	var weighted_sum := Vector3.ZERO
	var total_weight := 0.0
	for index in samples.size():
		var sample_value: Variant = samples[index]
		if not sample_value is Dictionary:
			reasons.append("COP_SAMPLE_INVALID:%d" % index)
			continue
		var sample: Dictionary = sample_value
		var point_value: Variant = sample.get("point_world")
		var weight_value: Variant = sample.get("normal_weight")
		if not point_value is Vector3 \
				or not (point_value as Vector3).is_finite() \
				or not (weight_value is float or weight_value is int) \
				or not is_finite(float(weight_value)) \
				or float(weight_value) < 0.0:
			reasons.append("COP_SAMPLE_INVALID:%d" % index)
			continue
		var weight := float(weight_value)
		weighted_sum += (point_value as Vector3) * weight
		total_weight += weight
	if not reasons.is_empty():
		return FrozenValueScript.snapshot({
			"schema_version": "center_of_pressure_v1",
			"finite": false,
			"center_of_pressure_world": null,
			"total_normal_weight": null,
			"invalid_reasons": reasons,
		})
	if total_weight <= 0.0 or not is_finite(total_weight):
		return FrozenValueScript.snapshot({
			"schema_version": "center_of_pressure_v1",
			"finite": false,
			"center_of_pressure_world": null,
			"total_normal_weight": total_weight,
			"invalid_reasons": ["COP_TOTAL_WEIGHT_NOT_POSITIVE"],
		})
	var center := weighted_sum / total_weight
	return FrozenValueScript.snapshot({
		"schema_version": "center_of_pressure_v1",
		"finite": center.is_finite(),
		"center_of_pressure_world": center if center.is_finite() else null,
		"total_normal_weight": total_weight,
		"invalid_reasons": [] if center.is_finite() \
			else ["COP_AGGREGATION_NONFINITE"],
	})


static func _classify_and_evaluate(
		hull: Array[Vector2],
		query: Vector2,
		segment_radius_m: float,
		tolerance: float) -> Dictionary:
	if hull.size() == 1:
		var point_distance := query.distance_to(hull[0])
		return {
			"support_kind": "POINT",
			"support_dimension": 0,
			"inside": point_distance <= tolerance,
			"signed_margin_m": -point_distance,
			"distance_to_support_m": point_distance,
			"support_area_m2": 0.0,
			"support_length_m": 0.0,
		}
	if hull.size() == 2:
		var closest := _closest_point_on_segment(
			query, hull[0], hull[1])
		var distance := query.distance_to(closest)
		var inside := distance <= segment_radius_m + tolerance
		return {
			"support_kind": "CAPSULE" if segment_radius_m > 0.0 \
				else "SEGMENT",
			"support_dimension": 1,
			"inside": inside,
			"signed_margin_m": segment_radius_m - distance,
			"distance_to_support_m": maxf(
				distance - segment_radius_m, 0.0),
			"support_area_m2": 0.0,
			"support_length_m": hull[0].distance_to(hull[1]),
		}

	var minimum_edge_margin := INF
	var inside_polygon := true
	var area_twice := 0.0
	var minimum_distance := INF
	for index in hull.size():
		var start := hull[index]
		var finish := hull[(index + 1) % hull.size()]
		var edge := finish - start
		var edge_length := edge.length()
		var edge_margin := edge.cross(query - start) / edge_length
		minimum_edge_margin = minf(minimum_edge_margin, edge_margin)
		if edge_margin < -tolerance:
			inside_polygon = false
		minimum_distance = minf(
			minimum_distance,
			query.distance_to(_closest_point_on_segment(
				query, start, finish)))
		area_twice += start.cross(finish)
	return {
		"support_kind": "POLYGON",
		"support_dimension": 2,
		"inside": inside_polygon,
		"signed_margin_m": minimum_edge_margin,
		"distance_to_support_m": (
			0.0 if inside_polygon else minimum_distance),
		"support_area_m2": 0.5 * absf(area_twice),
		"support_length_m": 0.0,
	}


static func _convex_hull(
		points: Array[Vector2],
		tolerance: float) -> Array[Vector2]:
	if points.size() <= 1:
		return points.duplicate()
	var sorted: Array[Vector2] = points.duplicate()
	sorted.sort_custom(func(left: Vector2, right: Vector2) -> bool:
		return left.x < right.x \
			or (left.x == right.x and left.y < right.y))
	var lower: Array[Vector2] = []
	for point in sorted:
		while lower.size() >= 2 and _turn(
				lower[lower.size() - 2],
				lower[lower.size() - 1],
				point) <= tolerance * tolerance:
			lower.pop_back()
		lower.append(point)
	var upper: Array[Vector2] = []
	for reverse_index in range(sorted.size() - 1, -1, -1):
		var point: Vector2 = sorted[reverse_index]
		while upper.size() >= 2 and _turn(
				upper[upper.size() - 2],
				upper[upper.size() - 1],
				point) <= tolerance * tolerance:
			upper.pop_back()
		upper.append(point)
	lower.pop_back()
	upper.pop_back()
	lower.append_array(upper)
	return lower


static func _turn(origin: Vector2, first: Vector2, second: Vector2) -> float:
	return (first - origin).cross(second - origin)


static func _closest_point_on_segment(
		query: Vector2,
		start: Vector2,
		finish: Vector2) -> Vector2:
	var delta := finish - start
	var length_squared := delta.length_squared()
	if length_squared <= NORMAL_EPSILON:
		return start
	var parameter := clampf(
		(query - start).dot(delta) / length_squared, 0.0, 1.0)
	return start + parameter * delta


static func _contains_near(
		points: Array[Vector2],
		candidate: Vector2,
		tolerance: float) -> bool:
	for point in points:
		if point.distance_to(candidate) <= tolerance:
			return true
	return false


static func _plane_axes(normal: Vector3) -> Array[Vector3]:
	var reference := Vector3.RIGHT \
		if absf(normal.dot(Vector3.RIGHT)) < 0.9 else Vector3.UP
	var axis_u := normal.cross(reference).normalized()
	var axis_v := normal.cross(axis_u).normalized()
	return [axis_u, axis_v]


static func _invalid(reasons: Array[String]) -> Dictionary:
	return FrozenValueScript.snapshot({
		"schema_version": SCHEMA_VERSION,
		"finite": false,
		"invalid_reasons": reasons,
		"support_kind": "UNAVAILABLE",
		"support_dimension": null,
		"hull_points_world": null,
		"query_inside_support": false,
		"signed_margin_m": null,
		"distance_to_support_m": null,
		"support_area_m2": null,
		"support_length_m": null,
	})
