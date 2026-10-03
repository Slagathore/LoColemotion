extends RefCounted
const FiniteRoute := preload("res://sdk/adapters/godot/gdscript/recovery_finite_cycle_route_v1.gd")

## Empty selection is the exact historical bridge. The named development
## successor changes only resumed walking, never the prefix or kick direction.
const CONTRACT_PATH := "res://sdk/development/recovery_walking_frame_contract_v1.json"
static var _contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))

static func valid_selection_v1(frame_id: Variant) -> bool:
	return frame_id is String and frame_id in ["", _contract["resume_frame_id"]]

static func frame_v1(basis: Basis, segment_id: String, frame_id: String = "") -> Dictionary:
	if not valid_selection_v1(frame_id) or (not frame_id.is_empty() and segment_id != _contract["segment_id"]):
		return {"ok": false, "failure_code": "DEVELOPMENT_WALKING_FRAME_SELECTION_INVALID"}
	if not basis.is_finite():
		return {"ok": false, "failure_code": "DEVELOPMENT_WALKING_FRAME_BASIS_INVALID"}
	var legacy_forward := -basis.z.normalized()
	var lateral := basis.x.normalized()
	var forward := legacy_forward
	if not frame_id.is_empty():
		# Match the established walking launcher. Its heading API is a separate
		# legacy convention: do NOT rotate its yaw argument along with the frame.
		lateral = basis.z
		lateral.y = 0.0
		if lateral.length_squared() <= 1.0e-12:
			return {"ok": false, "failure_code": "DEVELOPMENT_WALKING_FRAME_HORIZONTAL_AXIS_MISSING"}
		lateral = lateral.normalized()
		forward = Vector3.UP.cross(lateral).normalized()
	return {"ok": true, "forward": forward, "lateral": lateral,
		"legacy_yaw_rad": atan2(legacy_forward.x, -legacy_forward.z)}

static func trace_forward_v1(basis: Basis, frame_id: String = "") -> Vector3:
	# The evaluator projects this anatomical direction onto the horizontal
	# plane for heading drift. Never substitute a better direction after a run.
	return -basis.z.normalized() if frame_id.is_empty() else basis.x.normalized()

static func report_selection_valid_v1(arm: Dictionary, frame_id: String, route_id: String = "") -> bool:
	# Bind the retained interpretation to the prospective profile. Geometric
	# correctness is exercised at the actual adapter and evaluator boundaries.
	if not (arm.get("walking_sessions", []) is Array) or not (arm.get("trace_rows", []) is Array):
		return false
	for session in arm.get("walking_sessions", []):
		if not (session is Dictionary) or not (session.get("start_receipt", {}) is Dictionary):
			return false
		var expected := frame_id if FiniteRoute.segment_selected_v1(route_id, session.get("evaluation_segment_id", "")) else ""
		if session.get("start_receipt", {}).get("development_walking_frame_id", "") != expected:
			return false
	for row in arm.get("trace_rows", []):
		if not (row is Dictionary):
			return false
		var expected := frame_id if FiniteRoute.segment_selected_v1(route_id, row.get("walking_segment_id", "")) else ""
		if row.get("development_walking_frame_id", "") != expected:
			return false
	return valid_selection_v1(frame_id)
