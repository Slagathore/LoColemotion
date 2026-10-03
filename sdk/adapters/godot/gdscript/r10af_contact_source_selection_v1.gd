extends RefCounted
## Admit the explicit R10AF source profile without weakening legacy provenance.
## Full native point/geometry verification remains mandatory in contact replay.
const Frame := preload("res://sdk/adapters/godot/gdscript/recovery_detection_frame_contacts_v1.gd")
const AGGREGATION := "godot_jolt_detection_frame_distal_capsule_lower_cap_contact_v1"

static func aggregation_v1(source: Dictionary, legacy: String) -> String:
	if source.get("schema_version") != Frame.SOURCE_SCHEMA:
		return "" if source.has("contact_detection_frame") else legacy
	var frame: Variant = source.get("contact_detection_frame")
	if not frame is Dictionary or frame.get("schema_version") != Frame.FRAME_SCHEMA or frame.get("profile_id") != Frame.PROFILE:
		return ""
	if frame.get("classification_scope") != "distal_foot_cap_only" or not frame.get("native_space_step_sequence") is int:
		return ""
	if frame.native_space_step_sequence < 1 or frame.native_space_step_sequence != source.get("native_space_step_sequence"):
		return ""
	var snapshot: Variant = frame.get("native_snapshot")
	if not snapshot is Dictionary or snapshot.get("capture_space_step_sequence") != frame.native_space_step_sequence or snapshot.get("read_space_step_sequence") != frame.native_space_step_sequence:
		return ""
	return AGGREGATION
