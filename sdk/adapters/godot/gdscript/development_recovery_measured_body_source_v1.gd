extends RefCounted
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const FRAME := "sporespore_state_world_y_up_metres_v1"
const IDS := ["torso", "front_left_upper", "front_left_distal", "front_right_upper", "front_right_distal", "rear_left_upper", "rear_left_distal", "rear_right_upper", "rear_right_distal"]

static func project_v1(state: Dictionary, stability: Dictionary) -> Dictionary:
	var bodies: Variant = stability.get("ordered_body_states")
	if stability.get("semantic_step") != state.get("semantic_step") or stability.get("adapter_capability_sha256") != state.get("adapter_capability_sha256") or not (bodies is Array) or bodies.size() != IDS.size():
		return {}
	for index in range(IDS.size()):
		if not (bodies[index] is Dictionary) or bodies[index].get("body_id") != IDS[index]:
			return {}
	if Transport.stringify(bodies[0].get("pose_world")) != Transport.stringify(state.get("base_pose_world")) or Transport.stringify(bodies[0].get("twist_world")) != Transport.stringify(state.get("base_twist_world")):
		return {}
	return {"schema_version": "sporespore_measured_walking_body_frame_v1", "frame_id": FRAME,
		"semantic_step": state["semantic_step"], "sample_time_s": state["sample_time_s"],
		"adapter_capability_sha256": state["adapter_capability_sha256"], "source_measurement": true,
		"ordered_body_states": bodies.duplicate(true)}

static func retained_valid_v1(request: Dictionary, bodies: Array) -> bool:
	var state: Dictionary = request.get("state", {})
	var expected := project_v1(state, {"semantic_step": state.get("semantic_step"),
		"adapter_capability_sha256": state.get("adapter_capability_sha256"), "ordered_body_states": bodies})
	return not expected.is_empty() and Transport.stringify(request.get("measured_body_frame")) == Transport.stringify(expected)
