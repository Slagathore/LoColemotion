extends SceneTree

const Consumer := preload("res://sdk/adapters/godot/gdscript/recovery_contact_frames_v1.gd")
const NATIVE := &"JoltPhysicsServer3D"
const GET := &"space_get_contact_frames"
const ENABLE := &"space_set_contact_frames_enabled"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print("R10AC_CONTACT_FRAMES_ZERO_WORLD ", JSON.stringify(result))
	quit(0 if result.get("ok", false) else 1)


static func _snapshot() -> Dictionary:
	var pose := Transform3D(Basis(Vector3.BACK, 0.1), Vector3(0.3, 0.2, 0.0))
	var world := Vector3(0.02, 0.01, 0.0)
	var point := {
		"body1_jolt_id": 11, "body2_jolt_id": 22, "body1_instance_id": 111, "body2_instance_id": 222,
		"subshape1_id": 0, "subshape2_id": 0, "shape1_index": 0, "shape2_index": 0,
		"manifold_point_index": 0,
		"body1_transform_at_detection": pose, "body2_transform_at_detection": Transform3D.IDENTITY,
		"point1_world_m": world, "point2_world_m": world,
		"point1_body_local_m": pose.affine_inverse() * world, "point2_body_local_m": world,
		"normal1_world_unit": Vector3.UP, "normal2_world_unit": Vector3.DOWN,
		"impulse1_world_ns": Vector3(0.001, 0.02, 0.0), "impulse2_world_ns": Vector3(-0.001, -0.02, 0.0),
	}
	var snapshot := {"schema": Consumer.SCHEMA, "profile_id": Consumer.PROFILE,
		"capture_space_step_sequence": 7, "read_space_step_sequence": 7,
		"captured_during_active_step": true, "snapshot_is_current_space_step": true,
		"sampling_stage": "contact_detection_before_integration", "discrete_sampling_qualified": true,
		"reported_point_count": 1, "point_limit_exceeded": false, "complete": true, "points": [point]}
	for field in Consumer.ZERO_COUNTERS:
		snapshot[field] = 0
	return snapshot


static func _evaluate() -> Dictionary:
	for method in [GET, ENABLE]:
		if not ClassDB.class_has_method(NATIVE, method):
			return {"ok": false, "reason": "native_method_missing", "method": method}
	if ClassDB.class_call_static(NATIVE, GET, RID()) != null:
		return {"ok": false, "reason": "invalid_rid_read_accepted"}
	for enabled in [true, false]:
		if ClassDB.class_call_static(NATIVE, ENABLE, RID(), enabled) != false:
			return {"ok": false, "reason": "invalid_rid_enable_accepted"}
	var base := _snapshot()
	if not Consumer.validate_native_snapshot(base, 7).get("ok", false):
		return {"ok": false, "reason": "positive_refused", "detail": Consumer.validate_native_snapshot(base, 7)}
	var empty := base.duplicate(true)
	empty["points"] = []
	empty["reported_point_count"] = 0
	if not Consumer.validate_native_snapshot(empty, 7).get("ok", false):
		return {"ok": false, "reason": "complete_empty_refused"}
	var mutations: Array = []
	for field in ["complete", "discrete_sampling_qualified", "captured_during_active_step", "snapshot_is_current_space_step"]:
		var bad := base.duplicate(true)
		bad[field] = false
		mutations.append(bad)
	for field in Consumer.ZERO_COUNTERS:
		var bad := base.duplicate(true)
		bad[field] = 1
		mutations.append(bad)
	for pair in [["schema", "wrong"], ["profile_id", "wrong"], ["sampling_stage", "unqualified_contact_callback"],
		["capture_space_step_sequence", 6], ["read_space_step_sequence", 6], ["point_limit_exceeded", true],
		["reported_point_count", 2], ["reported_point_count", 1.0], ["complete", 1]]:
		var bad := base.duplicate(true)
		bad[pair[0]] = pair[1]
		mutations.append(bad)
	for pair in [["point1_world_m", Vector3(NAN, 0, 0)], ["point1_body_local_m", Vector3.ZERO],
		["normal1_world_unit", Vector3.RIGHT], ["normal1_world_unit", Vector3.UP * 2],
		["impulse1_world_ns", Vector3.ZERO], ["manifold_point_index", 1], ["shape1_index", -1],
		["body1_jolt_id", 22], ["body1_transform_at_detection", Transform3D(Basis.IDENTITY, Vector3.ZERO)],
		["body1_transform_at_detection", Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)]]:
		var bad := base.duplicate(true)
		bad["points"][0][pair[0]] = pair[1]
		mutations.append(bad)
	var duplicate := base.duplicate(true)
	duplicate["points"].append(duplicate["points"][0].duplicate(true))
	duplicate["reported_point_count"] = 2
	mutations.append(duplicate)
	for field in Consumer.ZERO_COUNTERS:
		var bad := base.duplicate(true)
		bad.erase(field)
		mutations.append(bad)
	mutations.append(null)
	var rejected := 0
	for bad in mutations:
		if Consumer.validate_native_snapshot(bad, 7).get("ok", false):
			return {"ok": false, "reason": "mutation_accepted", "mutation_index": rejected}
		rejected += 1
	# The returned array is detached; a consumer cannot mutate a cached snapshot.
	var accepted := Consumer.validate_native_snapshot(base, 7)
	accepted["points"][0]["body1_jolt_id"] = 999
	if base["points"][0]["body1_jolt_id"] != 11:
		return {"ok": false, "reason": "snapshot_alias"}
	return {"ok": true, "native_invalid_rid_refusals": 3, "synthetic_positive_cases": 2,
		"synthetic_negative_cases": rejected, "detached_snapshot_checked": true,
		"native_field_population_observed": false, "world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}
