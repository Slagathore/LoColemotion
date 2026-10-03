class_name LabSpatialDynamicSupportObserver
extends RefCounted

## Read-only dynamic whole-system support-state observer.
##
## The observer extends the geometric COM/support-polygon measurement with
## mass-weighted COM velocity and a deliberately limited linearized capture
## projection:
##
##     x_capture = x_com + v_com / sqrt(g / h)
##
## Only the horizontal XZ projection is used. This is a controller-state
## signal for one bounded, approximately level support fixture; it is not a
## proof that the articulated body obeys a linear inverted-pendulum model.
## The observer never writes physics state and grants no contact-load,
## per-foot allocation, bearing, or locomotion authority.

const _EPSILON := 1.0e-12


static func observe(
	body_by_id: Dictionary, ordered_support_points_world: Array[Vector3], gravity_m_s2: float
) -> Dictionary:
	if body_by_id.is_empty():
		return _failure("SPATIAL_DYNAMIC_SUPPORT_BODY_SET_EMPTY")
	if ordered_support_points_world.is_empty():
		return _failure("SPATIAL_DYNAMIC_SUPPORT_SET_EMPTY")
	if not is_finite(gravity_m_s2) or gravity_m_s2 <= 0.0:
		return _failure("SPATIAL_DYNAMIC_SUPPORT_GRAVITY_INVALID")

	var whole_mass_kg := 0.0
	var weighted_position := Vector3.ZERO
	var weighted_velocity := Vector3.ZERO
	for body_value in body_by_id.values():
		if not body_value is RigidBody3D:
			return _failure("SPATIAL_DYNAMIC_SUPPORT_BODY_INVALID")
		var body: RigidBody3D = body_value
		if (
			not is_finite(body.mass)
			or body.mass <= 0.0
			or not body.global_position.is_finite()
			or not body.linear_velocity.is_finite()
		):
			return _failure("SPATIAL_DYNAMIC_SUPPORT_BODY_STATE_INVALID")
		whole_mass_kg += body.mass
		weighted_position += body.mass * body.global_position
		weighted_velocity += body.mass * body.linear_velocity
	if whole_mass_kg <= 0.0:
		return _failure("SPATIAL_DYNAMIC_SUPPORT_MASS_INVALID")

	var support_result := _support_metrics(ordered_support_points_world)
	if not bool(support_result.get("ok", false)):
		return support_result
	var vertices: Array[Vector2] = support_result["vertices"]
	var support_plane_height_m := float(support_result["mean_height_m"])
	var center_of_mass := weighted_position / whole_mass_kg
	var center_of_mass_velocity := weighted_velocity / whole_mass_kg
	var center_of_mass_height_m := center_of_mass.y - support_plane_height_m
	if not is_finite(center_of_mass_height_m) or center_of_mass_height_m <= _EPSILON:
		return _failure("SPATIAL_DYNAMIC_SUPPORT_COM_HEIGHT_INVALID")

	var natural_frequency_rad_s := sqrt(gravity_m_s2 / center_of_mass_height_m)
	if not is_finite(natural_frequency_rad_s) or natural_frequency_rad_s <= 0.0:
		return _failure("SPATIAL_DYNAMIC_SUPPORT_NATURAL_FREQUENCY_INVALID")
	var capture_point := center_of_mass
	capture_point.x += center_of_mass_velocity.x / natural_frequency_rad_s
	capture_point.z += center_of_mass_velocity.z / natural_frequency_rad_s

	var center_of_mass_xz := Vector2(center_of_mass.x, center_of_mass.z)
	var capture_point_xz := Vector2(capture_point.x, capture_point.z)
	var support_dimension := int(support_result["support_geometry_dimension"])
	var center_of_mass_margin_m := _support_set_margin(
		center_of_mass_xz,
		vertices,
		support_dimension,
	)
	var capture_margin_m := _support_set_margin(
		capture_point_xz,
		vertices,
		support_dimension,
	)
	var centroid_xz: Vector2 = support_result["centroid_xz"]
	var support_centroid := Vector3(centroid_xz.x, support_plane_height_m, centroid_xz.y)
	var support_centroid_margin_m := _support_set_margin(
		centroid_xz,
		vertices,
		support_dimension,
	)
	var serialized_vertices: Array = []
	for vertex in vertices:
		serialized_vertices.append([vertex.x, vertex.y])

	return {
		"ok": true,
		"whole_system_mass_kg": whole_mass_kg,
		"center_of_mass_world_m": center_of_mass,
		"center_of_mass_velocity_world_m_s": center_of_mass_velocity,
		"support_plane_height_m": support_plane_height_m,
		"center_of_mass_height_above_support_m": center_of_mass_height_m,
		"linearized_natural_frequency_rad_s": natural_frequency_rad_s,
		"linearized_capture_point_world_m": capture_point,
		"support_centroid_world_m": support_centroid,
		"support_vertices_world_xz_m": serialized_vertices,
		"support_geometry_dimension": support_dimension,
		"support_geometry_kind": String(support_result["support_geometry_kind"]),
		"support_polygon_available": support_dimension == 2,
		"center_of_mass_margin_m": center_of_mass_margin_m,
		"linearized_capture_margin_m": capture_margin_m,
		"support_centroid_margin_m": support_centroid_margin_m,
		"minimum_dynamic_support_margin_m": minf(center_of_mass_margin_m, capture_margin_m),
		"center_of_mass_inside_or_boundary": center_of_mass_margin_m >= -1.0e-9,
		"linearized_capture_inside_or_boundary": capture_margin_m >= -1.0e-9,
		"linearized_capture_model_only": true,
		"articulated_capture_guarantee_available": false,
		"per_foot_measured_load_allocation_available": false,
		"contact_presence_is_bearing_measurement": false,
		"physics_state_modified": false,
	}


static func _support_metrics(points_world: Array[Vector3]) -> Dictionary:
	if points_world.is_empty():
		return _failure("SPATIAL_DYNAMIC_SUPPORT_SET_EMPTY")
	if points_world.size() >= 3:
		var polygon := _polygon_metrics(points_world)
		if bool(polygon.get("ok", false)):
			polygon["support_geometry_dimension"] = 2
			polygon["support_geometry_kind"] = "POLYGON"
		return polygon
	var vertices: Array[Vector2] = []
	var mean_height_m := 0.0
	for point in points_world:
		if not point.is_finite():
			return _failure("SPATIAL_DYNAMIC_SUPPORT_POINT_INVALID")
		vertices.append(Vector2(point.x, point.z))
		mean_height_m += point.y
	mean_height_m /= float(points_world.size())
	if points_world.size() == 1:
		return {
			"ok": true,
			"vertices": vertices,
			"mean_height_m": mean_height_m,
			"centroid_xz": vertices[0],
			"support_geometry_dimension": 0,
			"support_geometry_kind": "POINT",
		}
	if vertices[0].distance_to(vertices[1]) <= _EPSILON:
		return _failure("SPATIAL_DYNAMIC_SUPPORT_EDGE_DEGENERATE")
	return {
		"ok": true,
		"vertices": vertices,
		"mean_height_m": mean_height_m,
		"centroid_xz": 0.5 * (vertices[0] + vertices[1]),
		"support_geometry_dimension": 1,
		"support_geometry_kind": "SEGMENT",
	}


static func _polygon_metrics(points_world: Array[Vector3]) -> Dictionary:
	var vertices: Array[Vector2] = []
	var mean_height_m := 0.0
	for point in points_world:
		if not point.is_finite():
			return _failure("SPATIAL_DYNAMIC_SUPPORT_POINT_INVALID")
		vertices.append(Vector2(point.x, point.z))
		mean_height_m += point.y
	mean_height_m /= float(points_world.size())

	var signed_area_twice := 0.0
	for index in range(vertices.size()):
		var current := vertices[index]
		var next := vertices[(index + 1) % vertices.size()]
		if current.distance_to(next) <= _EPSILON:
			return _failure("SPATIAL_DYNAMIC_SUPPORT_EDGE_DEGENERATE")
		signed_area_twice += current.cross(next)
	if absf(signed_area_twice) <= _EPSILON:
		return _failure("SPATIAL_DYNAMIC_SUPPORT_POLYGON_DEGENERATE")
	if signed_area_twice < 0.0:
		vertices.reverse()
		signed_area_twice = -signed_area_twice

	for index in range(vertices.size()):
		var previous := vertices[(index - 1 + vertices.size()) % vertices.size()]
		var current := vertices[index]
		var next := vertices[(index + 1) % vertices.size()]
		if (current - previous).cross(next - current) < -1.0e-9:
			return _failure("SPATIAL_DYNAMIC_SUPPORT_POLYGON_NONCONVEX")

	var centroid_numerator := Vector2.ZERO
	for index in range(vertices.size()):
		var current := vertices[index]
		var next := vertices[(index + 1) % vertices.size()]
		var cross := current.cross(next)
		centroid_numerator += (current + next) * cross
	var centroid_xz := centroid_numerator / (3.0 * signed_area_twice)
	if not centroid_xz.is_finite():
		return _failure("SPATIAL_DYNAMIC_SUPPORT_CENTROID_INVALID")
	return {
		"ok": true,
		"vertices": vertices,
		"mean_height_m": mean_height_m,
		"centroid_xz": centroid_xz,
	}


static func _support_set_margin(
	point: Vector2,
	vertices: Array[Vector2],
	support_geometry_dimension: int,
) -> float:
	if support_geometry_dimension == 2:
		return _signed_margin(point, vertices)
	if support_geometry_dimension == 1:
		return -_distance_to_segment(point, vertices[0], vertices[1])
	return -point.distance_to(vertices[0])


static func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var edge := finish - start
	var fraction := clampf((point - start).dot(edge) / edge.length_squared(), 0.0, 1.0)
	return point.distance_to(start + fraction * edge)


static func _signed_margin(point: Vector2, vertices: Array[Vector2]) -> float:
	var minimum_signed_margin_m := INF
	for index in range(vertices.size()):
		var start := vertices[index]
		var finish := vertices[(index + 1) % vertices.size()]
		var edge := finish - start
		minimum_signed_margin_m = minf(
			minimum_signed_margin_m, edge.cross(point - start) / edge.length()
		)
	return minimum_signed_margin_m


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
