extends "res://sdk/adapters/godot/gdscript/r10am_capture_worker_v1.gd"
## Retain the hash chain from the original compact trace to each capture.
## This source component still inherits unconditional launch refusal.
const ContactReport := preload("res://sdk/adapters/godot/gdscript/r10af_contact_frame_report_v1.gd")
var _r10af_observation_links: Array = []


func _collect_arm_completed_step_v1(arm_id: String, global_step: int) -> Dictionary:
	var result := super._collect_arm_completed_step_v1(arm_id, global_step)
	_cost.begin_v1("r10af_contact_frame_link")
	var link := ContactReport.link_v1(_sdk, _arms[arm_id], global_step)
	_cost.end_v1("r10af_contact_frame_link")
	_r10af_observation_links.append(link)
	if result.get("ok") != true: return result
	return result if link.get("ok") == true else link


func _attach_profile_recovery_retention_v1(report: Dictionary) -> void:
	super._attach_profile_recovery_retention_v1(report)
	report["r10af_contact_frame_links"] = {"schema_version": ContactReport.LINKS_SCHEMA,
		"records": _r10af_observation_links.duplicate(true), "record_count": _r10af_observation_links.size(),
		"controller_observation_changed": true, "physical_acceptance_authority": false, "release_authority": false}
