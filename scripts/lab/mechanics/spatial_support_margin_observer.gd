class_name LabSpatialSupportMarginObserver
extends RefCounted

## Read-only whole-system COM margin against one ordered support polygon.
##
## The observer consumes body states and declared contact locations. It does
## not infer load allocation, bearing force, pressure, or contact quality, and
## it never writes physics state.


static func observe(
	body_by_id: Dictionary, ordered_support_points_world: Array[Vector3]
) -> Dictionary:
	if body_by_id.is_empty():
		return {"ok": false, "failure_code": "SPATIAL_SUPPORT_MARGIN_BODY_SET_EMPTY"}
	if ordered_support_points_world.size() < 3:
		return {"ok": false, "failure_code": "SPATIAL_SUPPORT_MARGIN_POLYGON_TOO_SMALL"}
	var whole_mass_kg := 0.0
	var weighted_position := Vector3.ZERO
	for body_value in body_by_id.values():
		if not body_value is RigidBody3D:
			return {"ok": false, "failure_code": "SPATIAL_SUPPORT_MARGIN_BODY_INVALID"}
		var body: RigidBody3D = body_value
		if not is_finite(body.mass) or body.mass <= 0.0 or not body.global_position.is_finite():
			return {"ok": false, "failure_code": "SPATIAL_SUPPORT_MARGIN_BODY_STATE_INVALID"}
		whole_mass_kg += body.mass
		weighted_position += body.mass * body.global_position
	if whole_mass_kg <= 0.0:
		return {"ok": false, "failure_code": "SPATIAL_SUPPORT_MARGIN_MASS_INVALID"}
	var center_of_mass := weighted_position / whole_mass_kg
	var vertices: Array[Vector2] = []
	for point in ordered_support_points_world:
		if not point.is_finite():
			return {"ok": false, "failure_code": "SPATIAL_SUPPORT_MARGIN_POINT_INVALID"}
		vertices.append(Vector2(point.x, point.z))
	var signed_area_twice := 0.0
	for index in range(vertices.size()):
		var current := vertices[index]
		var next := vertices[(index + 1) % vertices.size()]
		signed_area_twice += current.cross(next)
	if absf(signed_area_twice) <= 1.0e-12:
		return {"ok": false, "failure_code": "SPATIAL_SUPPORT_MARGIN_POLYGON_DEGENERATE"}
	if signed_area_twice < 0.0:
		vertices.reverse()
	var projected_com := Vector2(center_of_mass.x, center_of_mass.z)
	var minimum_signed_margin_m := INF
	for index in range(vertices.size()):
		var start := vertices[index]
		var finish := vertices[(index + 1) % vertices.size()]
		var edge := finish - start
		if edge.length() <= 1.0e-12:
			return {"ok": false, "failure_code": "SPATIAL_SUPPORT_MARGIN_EDGE_DEGENERATE"}
		var signed_distance := edge.cross(projected_com - start) / edge.length()
		minimum_signed_margin_m = minf(minimum_signed_margin_m, signed_distance)
	var serialized_vertices: Array = []
	for vertex in vertices:
		serialized_vertices.append([vertex.x, vertex.y])
	return {
		"ok": true,
		"whole_system_mass_kg": whole_mass_kg,
		"center_of_mass_world_m": center_of_mass,
		"support_vertices_world_xz_m": serialized_vertices,
		"minimum_signed_margin_m": minimum_signed_margin_m,
		"inside_or_boundary": minimum_signed_margin_m >= -1.0e-9,
		"per_foot_measured_load_allocation_available": false,
		"contact_presence_is_bearing_measurement": false,
		"physics_state_modified": false,
	}
