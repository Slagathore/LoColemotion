extends RefCounted
# gdlint: disable=max-line-length

## Scene-property provenance, not a contact/force measurement. The first route
## supports translated, unscaled axis-aligned boxes only. No implicit y=0.
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const POLICY_ID := "sporespore_balanced_wave_recovery_floor_support_v1"
const FRAME_ID := "sporespore_state_world_y_up_metres_v1"
const SOURCE_SCHEMA := "sporespore_development_constructed_box_floor_source_v1"

static func capture_v1(sdk: Object, floor: Variant, model_instance_id: String) -> Dictionary:
	if sdk == null or not (floor is StaticBody3D) or not is_instance_valid(floor) or model_instance_id.is_empty():
		return failure_v1("MISSING_NATIVE_SOURCE")
	if floor.get_meta("lab_body_id", "") != "floor" or floor.constant_linear_velocity != Vector3.ZERO or floor.constant_angular_velocity != Vector3.ZERO:
		return failure_v1("NOT_STATIC_FLOOR")
	var shapes: Array = floor.get_children().filter(func(node): return node is CollisionShape3D)
	if shapes.size() != 1 or floor.get_child_count() != 1:
		return failure_v1("SHAPE_POPULATION")
	var node: CollisionShape3D = shapes[0]
	if node.disabled or not (node.shape is BoxShape3D) or node.get_meta("lab_shape_id", "") != "floor":
		return failure_v1("SHAPE_KIND_OR_DISABLED")
	var chain := []
	var current: Node3D = node
	var composed := Transform3D.IDENTITY
	# Stop at a top-level node or a non-Node3D parent, exactly as Godot does.
	while current != null:
		if current.transform.basis != Basis.IDENTITY or not current.transform.origin.is_finite():
			return failure_v1("TRANSFORM_OUTSIDE_TRANSLATION_SUBSET")
		chain.append({"instance_id": str(current.get_instance_id()), "name": String(current.name),
			"top_level": current.top_level, "position_m": vector_v1(current.position)})
		composed = current.transform * composed
		current = null if current.top_level else current.get_parent() as Node3D
	if node.is_inside_tree() and node.global_transform != composed:
		return failure_v1("COMPOSED_GLOBAL_TRANSFORM_CROSSED")
	var size: Vector3 = node.shape.size
	if not size.is_finite() or minf(size.x, minf(size.y, size.z)) <= 0.0 or not is_finite(node.shape.margin):
		return failure_v1("SHAPE_DIMENSIONS")
	var geometry := {"schema_version": SOURCE_SCHEMA, "frame_id": FRAME_ID,
		"surface_id": "floor", "model_instance_id": model_instance_id,
		"floor_instance_id": str(floor.get_instance_id()), "shape_node_instance_id": str(node.get_instance_id()),
		"shape_resource_instance_id": str(node.shape.get_instance_id()),
		"shape_kind": "BoxShape3D", "size_m": vector_v1(size), "shape_margin_m": float(node.shape.margin),
		"collision_layer": floor.collision_layer, "collision_mask": floor.collision_mask,
		"transform_chain_shape_to_root": chain, "shape_center_world_m": vector_v1(composed.origin),
		"top_world_y_m": float(composed.origin.y) + float(size.y) / 2.0,
		"x_interval_m": [float(composed.origin.x) - float(size.x) / 2.0, float(composed.origin.x) + float(size.x) / 2.0],
		"z_interval_m": [float(composed.origin.z) - float(size.z) / 2.0, float(composed.origin.z) + float(size.z) / 2.0]}
	var reference := reference_v1(sdk, geometry)
	return {"ok": true, "geometry": geometry, "floor_reference": reference,
		"scene_property_source": true, "native_contact_measurement": false,
		"physical_acceptance_authority": false, "release_authority": false}

static func reference_v1(sdk: Object, geometry: Dictionary) -> Dictionary:
	return {"schema_version": "sporespore_static_horizontal_floor_reference_v1", "frame_id": FRAME_ID,
		"surface_id": geometry.get("surface_id"), "source_instance_id": geometry.get("model_instance_id", "") + ":floor:" + geometry.get("floor_instance_id", ""),
		"source_kind": "declared_static_horizontal_surface",
		"geometry_source_sha256": Runtime.canonicalize(sdk, geometry).get("sha256", ""),
		"height_world_m": geometry.get("top_world_y_m")}

static func verify_v1(sdk: Object, source: Dictionary, model_instance_id: String) -> bool:
	if sdk == null or model_instance_id.is_empty() or source.get("ok") != true or source.get("scene_property_source") != true or source.get("native_contact_measurement") != false or source.get("physical_acceptance_authority") != false or source.get("release_authority") != false:
		return false
	var g: Dictionary = source.get("geometry", {})
	if g.get("schema_version") != SOURCE_SCHEMA or g.get("frame_id") != FRAME_ID or g.get("surface_id") != "floor" or g.get("model_instance_id") != model_instance_id or g.get("shape_kind") != "BoxShape3D":
		return false
	for key in ["floor_instance_id", "shape_node_instance_id", "shape_resource_instance_id"]:
		# RefCounted resource IDs can occupy the sign bit of GDScript int64.
		# Preserve their exact decimal identity; zero, overflow and aliases refuse.
		if not instance_id_valid_v1(g.get(key)):
			return false
	var size: Variant = g.get("size_m")
	var chain: Variant = g.get("transform_chain_shape_to_root")
	if not vector_valid_v1(size) or not (chain is Array) or chain.size() < 2 or not number_v1(g.get("shape_margin_m")) or g["shape_margin_m"] < 0:
		return false
	if minf(size[0], minf(size[1], size[2])) <= 0 or g.get("collision_layer", 0) <= 0 or g.get("collision_mask", 0) <= 0:
		return false
	# Independent retained-source derivation: accumulate serialized offsets using
	# host Vector3 arithmetic, not the producer's Transform3D multiplication.
	var center := Vector3.ZERO
	var seen := {}
	for index in range(chain.size()):
		var row: Variant = chain[index]
		if not (row is Dictionary) or not vector_valid_v1(row.get("position_m")) or not instance_id_valid_v1(row.get("instance_id")) or seen.has(row["instance_id"]) or not (row.get("top_level") is bool):
			return false
		if row["top_level"] and index != chain.size() - 1:
			return false
		seen[row["instance_id"]] = true
		var p: Array = row["position_m"]
		center = Vector3(p[0], p[1], p[2]) + center
	if chain[0]["instance_id"] != g["shape_node_instance_id"] or chain[1]["instance_id"] != g["floor_instance_id"] or chain[0]["top_level"]:
		return false
	if not center.is_finite() or g.get("shape_center_world_m") != vector_v1(center):
		return false
	if g.get("top_world_y_m") != float(center.y) + float(size[1]) / 2.0 or g.get("x_interval_m") != [float(center.x) - float(size[0]) / 2.0, float(center.x) + float(size[0]) / 2.0] or g.get("z_interval_m") != [float(center.z) - float(size[2]) / 2.0, float(center.z) + float(size[2]) / 2.0]:
		return false
	return Transport.stringify(source.get("floor_reference")) == Transport.stringify(reference_v1(sdk, g))

static func applicable_v1(source: Dictionary, state: Dictionary, geometry: Dictionary) -> bool:
	var position: Dictionary = state.get("base_pose_world", {}).get("position_m", {})
	for axis in ["x", "y", "z"]:
		if not number_v1(position.get(axis)):
			return false
	var torso: Dictionary = geometry.get("torso_size_m", {})
	for key in ["upper_length_m", "lower_length_m", "foot_radius_m", "front_hip_x_m", "rear_hip_x_m", "left_hip_z_m", "right_hip_z_m"]:
		if not number_v1(geometry.get(key)):
			return false
	for axis in ["x", "y", "z"]:
		if not number_v1(torso.get(axis)):
			return false
	# Conservative orientation-independent reach around the torso: torso half
	# diagonal + largest hip offset + both links + foot radius. No floor-edge
	# success threshold is added; requests outside this geometric subset refuse.
	var radius := sqrt(torso.x * torso.x + torso.y * torso.y + torso.z * torso.z) / 2.0
	var hip_x := maxf(absf(geometry.front_hip_x_m), absf(geometry.rear_hip_x_m))
	var hip_z := maxf(absf(geometry.left_hip_z_m), absf(geometry.right_hip_z_m))
	radius += sqrt(hip_x * hip_x + hip_z * hip_z) + geometry.upper_length_m + geometry.lower_length_m + geometry.foot_radius_m
	var g: Dictionary = source.get("geometry", {})
	if not is_finite(radius) or radius <= 0.0:
		return false
	for axis in ["x", "z"]:
		var interval: Variant = g.get(axis + "_interval_m")
		if not (interval is Array) or interval.size() != 2 or not number_v1(interval[0]) or not number_v1(interval[1]) or position[axis] - radius < interval[0] or position[axis] + radius > interval[1]:
			return false
	return true

static func number_v1(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(value)

static func instance_id_valid_v1(value: Variant) -> bool:
	return value is String and value.is_valid_int() and value.to_int() != 0 and str(value.to_int()) == value

static func vector_valid_v1(value: Variant) -> bool:
	return value is Array and value.size() == 3 and value.all(number_v1)

static func vector_v1(value: Vector3) -> Array:
	return [float(value.x), float(value.y), float(value.z)]

static func failure_v1(code: String) -> Dictionary:
	return {"ok": false, "failure_code": "DEVELOPMENT_FLOOR_" + code}
