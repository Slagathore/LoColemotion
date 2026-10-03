extends RefCounted
## Exact admission for the finite diagnostic. It has no walking-resume policy.
const Seed := preload("res://sdk/adapters/godot/gdscript/r10dg_development_seed_v1.gd")

static func load_v1(reference: Variant, base: Dictionary) -> Dictionary:
	if not Seed.Json.same_json_v1(reference, {"resource": Seed.PROFILE, "raw_sha256": Seed.PROFILE_SHA}): return {}
	if "sha256:" + FileAccess.get_sha256(Seed.PROFILE) != Seed.PROFILE_SHA: return {}
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Seed.PROFILE))
	for key in ["runtime_binding", "extension"]:
		if "sha256:" + FileAccess.get_sha256(profile[key]) != profile[key + "_sha256"]: return {}
	var runtime: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile.runtime_binding))
	if runtime.runtime.raw_sha256 != profile.runtime_sha256: return {}
	for path in ["res://" + str(runtime.local_build_path), runtime.runtime.path]:
		if not FileAccess.file_exists(path) or "sha256:" + FileAccess.get_sha256(path) != profile.runtime_sha256: return {}
	var schedule_path := "res://sdk/development/recovery_schedules/r10dg-finite-reference-v1.json"
	if "sha256:" + FileAccess.get_sha256(schedule_path) != profile.diagnostic_schedule_sha256: return {}
	var schedule: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(schedule_path)).schedules[profile.diagnostic_schedule_id]
	var result := base.duplicate(true)
	result.candidate_profile = reference.duplicate(true)
	result.candidate = profile
	result.post_kick_controller_id = profile.post_kick_controller_id
	result.diagnostic_schedule = schedule
	result.worker_selection.merge({"worker": "res://sdk/adapters/godot/gdscript/r10dg_development_worker_v1.gd",
		"binding": profile.runtime_binding, "extension": profile.extension,
		"schedule": "r10dg_finite_reference_tracking_v1"}, true)
	result.reader = "res://sdk/trace_analysis/r10dg_recovery_replay.gd"
	result.input_schema = "sporespore_r10dg_recovery_replay_input_v1"
	result.report_input_schema = "sporespore_r10dg_recovery_report_replay_input_v1"
	result.retention_schema = "sporespore_r10df_recovery_entry_retention_v1"
	result.replay_receipt_schema = "sporespore_r10dg_recovery_replay_receipt_v1"
	result.diagnostic_reader_requires_declaration = true
	return result
