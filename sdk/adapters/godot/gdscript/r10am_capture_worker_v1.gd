extends "res://sdk/adapters/godot/gdscript/r10am_route_worker_v1.gd"

## Select the V27 route with the original R10AF detection-frame observation profile.
## Launch remains refused by the parent until a distinct seed/profile/launcher
## and complete applicable safety gate are prospectively qualified.
const ContactFrames := preload("res://sdk/adapters/godot/gdscript/r10af_contact_frame_capture_v1.gd")
var _r10af_contact_frame_records: Array = []


func _build_arm_v1(arm_id: String) -> Dictionary:
	var result: Dictionary = await super._build_arm_v1(arm_id)
	if result.get("ok") != true:
		return result
	_arms[arm_id].model[ContactFrames.Frame.MODEL_KEY] = ContactFrames.Frame.PROFILE
	return ContactFrames.enable_v1(_arms[arm_id].model)


func _collect_arm_completed_step_v1(arm_id: String, global_step: int) -> Dictionary:
	var result := super._collect_arm_completed_step_v1(arm_id, global_step)
	if result.get("ok") != true:
		return result
	_cost.begin_v1("r10af_contact_frame_capture")
	var capture := ContactFrames.capture_v1(_sdk, _arms[arm_id], global_step)
	_cost.end_v1("r10af_contact_frame_capture")
	# Keep rejected data as well; it must remain inspectable after an abort.
	_r10af_contact_frame_records.append(capture)
	return capture if capture.get("ok") != true else result


func _attach_profile_recovery_retention_v1(report: Dictionary) -> void:
	super._attach_profile_recovery_retention_v1(report)
	report["r10af_contact_frames"] = {
		"schema_version": "sporespore_r10af_contact_frame_retention_v1",
		"records": _r10af_contact_frame_records.duplicate(true),
		"record_count": _r10af_contact_frame_records.size(),
		"controller_observation_changed": true,
		"physical_acceptance_authority": false, "release_authority": false,
	}
