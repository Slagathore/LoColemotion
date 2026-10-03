extends RefCounted

## Pure diagnostic admission. This never substitutes contact-frame data for
## the controller's current observation or changes the foot-cap definition.

const SCHEMA := "sporespore.godot_jolt_contact_frames.v1"
const PROFILE := "godot_4_7_jolt_sporespore_contact_frames_v7"
const ZERO_COUNTERS := [
	"missing_manifold_count", "ccd_only_manifold_count", "point_count_mismatch_count",
	"nonfinite_impulse_count", "missing_frame_count", "duplicate_callback_count",
	"invalid_frame_count",
]
const ID_FIELDS := [
	"body1_jolt_id", "body2_jolt_id", "body1_instance_id", "body2_instance_id",
	"subshape1_id", "subshape2_id", "shape1_index", "shape2_index", "manifold_point_index",
]


static func validate_native_snapshot(value: Variant, expected_step: int) -> Dictionary:
	if not value is Dictionary or expected_step <= 0:
		return _failure("snapshot_type_or_expected_step")
	var snapshot: Dictionary = value
	if snapshot.get("schema") != SCHEMA or snapshot.get("profile_id") != PROFILE:
		return _failure("schema_or_profile")
	if snapshot.get("sampling_stage") != "contact_detection_before_integration":
		return _failure("sampling_stage")
	for field in ["complete", "discrete_sampling_qualified", "captured_during_active_step", "snapshot_is_current_space_step"]:
		if not snapshot.get(field) is bool or snapshot[field] != true:
			return _failure(field)
	if not snapshot.get("point_limit_exceeded") is bool or snapshot["point_limit_exceeded"]:
		return _failure("point_limit_exceeded")
	for field in ["capture_space_step_sequence", "read_space_step_sequence"]:
		if not snapshot.get(field) is int or snapshot[field] != expected_step:
			return _failure(field)
	for field in ZERO_COUNTERS:
		if not snapshot.get(field) is int or snapshot[field] != 0:
			return _failure(field)
	if not snapshot.get("points") is Array or not snapshot.get("reported_point_count") is int:
		return _failure("point_population")
	var points: Array = snapshot["points"]
	if points.size() > 4096 or points.size() != snapshot["reported_point_count"]:
		return _failure("point_count")
	var keys := {}
	var populations := {}
	var body_bindings := {}
	for item in points:
		if not item is Dictionary:
			return _failure("point_type")
		var point: Dictionary = item
		for field in ID_FIELDS:
			if not point.get(field) is int or point[field] < 0:
				return _failure(field)
		if point["body1_jolt_id"] == point["body2_jolt_id"]:
			return _failure("same_body_pair")
		var pair := "%d:%d|%d:%d" % [point["body1_jolt_id"], point["subshape1_id"], point["body2_jolt_id"], point["subshape2_id"]]
		var key := "%s:%d" % [pair, point["manifold_point_index"]]
		if keys.has(key):
			return _failure("duplicate_point")
		keys[key] = true
		if not populations.has(pair):
			populations[pair] = []
		populations[pair].append(point["manifold_point_index"])
		for side in ["1", "2"]:
			var body_id: int = point["body" + side + "_jolt_id"]
			var instance_id: int = point["body" + side + "_instance_id"]
			if body_bindings.has(body_id) and body_bindings[body_id] != instance_id:
				return _failure("body_identity_changed")
			body_bindings[body_id] = instance_id
			var transform_key: String = "body" + side + "_transform_at_detection"
			if not point.get(transform_key) is Transform3D:
				return _failure(transform_key)
			var pose: Transform3D = point[transform_key]
			if not pose.is_finite() or is_zero_approx(pose.basis.determinant()):
				return _failure("invalid_transform")
			for field in ["point" + side + "_world_m", "point" + side + "_body_local_m", "normal" + side + "_world_unit", "impulse" + side + "_world_ns"]:
				if not point.get(field) is Vector3 or not (point[field] as Vector3).is_finite():
					return _failure(field)
			var world: Vector3 = point["point" + side + "_world_m"]
			var local: Vector3 = point["point" + side + "_body_local_m"]
			# Both values originate from the same native float transform operation.
			# A later transform is not an admissible substitute, even if nearby.
			if pose.affine_inverse() * world != local:
				return _failure("contact_frame_roundtrip")
			var normal: Vector3 = point["normal" + side + "_world_unit"]
			if absf(normal.length() - 1.0) > 1.0e-6:
				return _failure("normal_length")
		if point["normal1_world_unit"] != -point["normal2_world_unit"]:
			return _failure("normal_pair")
		if point["impulse1_world_ns"] != -point["impulse2_world_ns"]:
			return _failure("impulse_pair")
	for indices in populations.values():
		indices.sort()
		if indices != range(indices.size()):
			return _failure("point_index_gap")
	return {"ok": true, "points": points.duplicate(true), "point_count": points.size(),
		"capture_space_step_sequence": expected_step, "world_build_count": 0,
		"solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}


static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "world_build_count": 0,
		"solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}
