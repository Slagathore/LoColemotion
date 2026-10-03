extends RefCounted
## Exact R10AG schedule admission. Retained reports are never translated.
const Seed := preload("res://sdk/adapters/godot/gdscript/r10ag_development_seed_v1.gd")
const ENTRY := "r10ag_v56_joint_bounded_contact_gated_v1"
const START := "r10ag_v56_front_left_first_post_interaction_v1"

static func native_schedule_v1(schedule: Dictionary) -> Dictionary:
	if "sha256:" + FileAccess.get_sha256(Seed.PROFILE) != Seed.PROFILE_SHA: return {}
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Seed.PROFILE))
	var path: String = "res://sdk/development/recovery_schedules/" + profile.diagnostic_schedule_id + ".json"
	if "sha256:" + FileAccess.get_sha256(path) != profile.diagnostic_schedule_sha256: return {}
	var schedules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not Seed.Json.same_json_v1(schedule, schedules.schedules[profile.diagnostic_schedule_id]): return {}
	var result := schedule.duplicate(true)
	return result
