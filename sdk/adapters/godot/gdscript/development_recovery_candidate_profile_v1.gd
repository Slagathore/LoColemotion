extends RefCounted
# gdlint: disable=max-line-length

## Load once before SDK/model creation. No ambient controller or DLL overrides.
const CONTRACT_PATH := "res://sdk/development_recovery_candidate_contract_v1.json"
const SCHEDULES_PATH := "res://sdk/development_recovery_candidate_schedules_v1.json"
const WalkingFrame := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_frame_v1.gd")
const WalkingStart := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_start_v1.gd")
const WalkingPolicy := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_policy_v1.gd")
const WalkingEntry := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_entry_v1.gd")
const WalkingContacts := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_contacts_v1.gd")
const NativeWalkingContacts := preload("res://sdk/adapters/godot/gdscript/development_recovery_native_walking_contacts_v1.gd")
const DEFAULT_LIMITS := {"maximum_precondition_steps": 320, "walking_prefix_steps": 30,
	"interaction_steps": 1, "maximum_passive_descent_steps": 240,
	"after_interaction_steps": 480, "maximum_steps_per_child": 832}
static var _contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
static var _walking_replay_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_prospective_walking_replay_contract_v1.json"))

static func contract_v1() -> Dictionary:
	return _contract.duplicate(true)

static func _resource_valid(value: Variant, prefix: String = "res://sdk/") -> bool:
	return (value is String and value.begins_with(prefix) and not "\\" in value
		and value.simplify_path() == value and FileAccess.file_exists(value))

static func schedule_path_v1(id: String) -> String:
	var pattern := RegEx.new()
	pattern.compile("^[a-z0-9][a-z0-9-]{0,79}$")
	if pattern.search(id) == null:
		return ""
	var path := "res://sdk/development/recovery_schedules/" + id + ".json"
	return path if FileAccess.file_exists(path) else SCHEDULES_PATH

static func load_v1(reference: Variant) -> Dictionary:
	if reference is Dictionary and reference.get("resource") == "res://sdk/development/recovery_candidates/r10dg-finite-reference-v1.json":
		return preload("res://sdk/adapters/godot/gdscript/r10dg_diagnostic_profile_v1.gd").load_v1(reference, contract_v1())
	if not (reference is Dictionary) or reference.size() != 2:
		return {}
	var path: Variant = reference.get("resource")
	if (not _resource_valid(path, "res://sdk/development/recovery_candidates/")
		or not path.ends_with(".json") or not (reference.get("raw_sha256") is String)
		or "sha256:" + FileAccess.get_sha256(path) != reference["raw_sha256"]):
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var schedules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCHEDULES_PATH))
	var scheduled: bool = value is Dictionary and value.get("schema_version") == schedules["profile_schema"]
	var keys: Array = _contract["profile_keys"].duplicate()
	if scheduled:
		keys.append_array(schedules["extra_profile_keys"])
	if not (value is Dictionary) or value.size() != keys.size():
		return {}
	for key in keys:
		if not (value.get(key) is String) or value[key].is_empty():
			return {}
	var pattern := RegEx.new()
	pattern.compile("^[a-z0-9][a-z0-9-]{0,79}$")
	if pattern.search(value["candidate_id"]) == null:
		return {}
	pattern.compile("^sporespore_exact_s169_prone_to_standing_controller_v([7-9]|[1-9][0-9]+)$")
	if pattern.search(value["post_kick_controller_id"]) == null or (not scheduled and value["schema_version"] != _contract["profile_schema"]):
		return {}
	for key in ["runtime_binding", "extension"]:
		if not _resource_valid(value[key]) or "sha256:" + FileAccess.get_sha256(value[key]) != value[key + "_sha256"]:
			return {}
	var binding: Variant = JSON.parse_string(FileAccess.get_file_as_string(value["runtime_binding"]))
	if (not (binding is Dictionary) or not (binding.get("runtime") is Dictionary)
		or binding["runtime"].get("raw_sha256") != value["runtime_sha256"]):
		return {}
	for image in ["res://" + String(binding.get("local_build_path", "")), binding["runtime"].get("path", "")]:
		if not FileAccess.file_exists(image) or "sha256:" + FileAccess.get_sha256(image) != value["runtime_sha256"]:
			return {}
	var result := contract_v1()
	result["candidate_profile"] = reference.duplicate(true)
	result["candidate"] = value.duplicate(true)
	result["post_kick_controller_id"] = value["post_kick_controller_id"]
	result["worker_selection"]["binding"] = value["runtime_binding"]
	result["worker_selection"]["extension"] = value["extension"]
	if scheduled:
		var schedule_path := schedule_path_v1(value["diagnostic_schedule_id"])
		if schedule_path.is_empty() or value["diagnostic_schedule_sha256"] != "sha256:" + FileAccess.get_sha256(schedule_path):
			return {}
		schedules = JSON.parse_string(FileAccess.get_file_as_string(schedule_path))
		var schedule: Variant = schedules["schedules"].get(value["diagnostic_schedule_id"])
		if (not (schedule is Dictionary) or schedule.get("controller_id") != value["post_kick_controller_id"]
			or schedule.get("runtime_sha256") != value["runtime_sha256"]
			or typeof(schedule.get("physical_acceptance_authority")) != TYPE_BOOL or schedule["physical_acceptance_authority"]
			or typeof(schedule.get("release_authority")) != TYPE_BOOL or schedule["release_authority"]):
			return {}
		var bounds: Variant = schedule.get("limits")
		if not (bounds is Dictionary) or bounds.size() != DEFAULT_LIMITS.size():
			return {}
		for key in DEFAULT_LIMITS:
			var bound: Variant = bounds.get(key)
			if typeof(bound) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(bound) or bound != int(bound):
				return {}
			if key not in ["after_interaction_steps", "maximum_steps_per_child"] and bound != DEFAULT_LIMITS[key]:
				return {}
		if bounds["after_interaction_steps"] <= 480 or bounds["after_interaction_steps"] > 4096 or bounds["maximum_steps_per_child"] != 352 + bounds["after_interaction_steps"]:
			return {}
		if not WalkingFrame.valid_selection_v1(schedule.get("walking_resume_frame_id", "")):
			return {}
		if not WalkingEntry.valid_selection_v1(schedule.get("walking_entry_profile_id", "")):
			return {}
		if not walking_replay_selection_valid_v1(schedule):
			return {}
		if not WalkingStart.schedule_valid_v1(schedule):
			return {}
		if not WalkingPolicy.schedule_valid_v1(schedule):
			return {}
		if not WalkingContacts.valid_selection_v1(schedule.get("walking_contact_profile_id", "")) and not NativeWalkingContacts.selected_v1(schedule.get("walking_contact_profile_id", "")):
			return {}
		if not String(schedule.get("walking_contact_profile_id", "")).is_empty() and String(schedule.get("walking_entry_profile_id", "")).is_empty():
			return {}
		result["diagnostic_schedule"] = schedule.duplicate(true)
		if schedule.get("walking_policy_id") == WalkingPolicy.R10AP.ID:
			result.worker_selection.worker = "res://sdk/adapters/godot/gdscript/r10ap_development_worker_v1.gd"
			result.reader = "res://sdk/trace_analysis/r10ap_recovery_replay.gd"
			result.input_schema = "sporespore_r10ap_recovery_replay_input_v1"
			result.report_input_schema = "sporespore_r10ap_recovery_report_replay_input_v1"
			result.retention_schema = "sporespore_r10ap_recovery_entry_retention_v1"
			result.replay_receipt_schema = "sporespore_r10ap_recovery_replay_receipt_v1"
		if schedule.get("walking_policy_id") == WalkingPolicy.R10AM.ID:
			result.worker_selection.worker = "res://sdk/adapters/godot/gdscript/r10am_development_worker_v1.gd"
			result.reader = "res://sdk/trace_analysis/r10am_recovery_replay.gd"
			result.input_schema = "sporespore_r10am_recovery_replay_input_v1"
			result.report_input_schema = "sporespore_r10am_recovery_report_replay_input_v1"
			result.retention_schema = "sporespore_r10am_recovery_entry_retention_v1"
			result.replay_receipt_schema = "sporespore_r10am_recovery_replay_receipt_v1"
		if schedule.get("walking_policy_id") == WalkingPolicy.R10AJ.ID:
			result.worker_selection.worker = "res://sdk/adapters/godot/gdscript/r10aj_development_worker_v1.gd"
			result.reader = "res://sdk/trace_analysis/r10aj_recovery_replay.gd"
			result.input_schema = "sporespore_r10aj_recovery_replay_input_v1"
			result.report_input_schema = "sporespore_r10aj_recovery_report_replay_input_v1"
			result.retention_schema = "sporespore_r10aj_recovery_entry_retention_v1"
			result.replay_receipt_schema = "sporespore_r10aj_recovery_replay_receipt_v1"
		if schedule.get("walking_policy_id") == WalkingPolicy.R10AI.ID:
			result.worker_selection.worker = "res://sdk/adapters/godot/gdscript/r10ai_development_worker_v1.gd"
			result.reader = "res://sdk/trace_analysis/r10ai_recovery_replay.gd"
			result.input_schema = "sporespore_r10ai_recovery_replay_input_v1"
			result.report_input_schema = "sporespore_r10ai_recovery_report_replay_input_v1"
			result.retention_schema = "sporespore_r10ai_recovery_entry_retention_v1"
			result.replay_receipt_schema = "sporespore_r10ai_recovery_replay_receipt_v1"
		if schedule.get("walking_policy_id") == WalkingPolicy.R10AG.ID:
			result.worker_selection.worker = "res://sdk/adapters/godot/gdscript/r10ag_development_worker_v1.gd"
			result.reader = "res://sdk/trace_analysis/r10ag_recovery_replay.gd"
			result.input_schema = "sporespore_r10ag_recovery_replay_input_v1"
			result.report_input_schema = "sporespore_r10ag_recovery_report_replay_input_v1"
			result.retention_schema = "sporespore_r10ag_recovery_entry_retention_v1"
			result.replay_receipt_schema = "sporespore_r10ag_recovery_replay_receipt_v1"
		if schedule.get("walking_policy_id") == WalkingPolicy.R10AB.ID:
			result.worker_selection.worker = "res://sdk/adapters/godot/gdscript/r10ab_development_worker_v1.gd"
			result.reader = "res://sdk/trace_analysis/r10ab_recovery_replay.gd"
			result.input_schema = "sporespore_r10ab_recovery_replay_input_v1"
			result.report_input_schema = "sporespore_r10ab_recovery_report_replay_input_v1"
			result.retention_schema = "sporespore_r10ab_recovery_entry_retention_v1"
			result.replay_receipt_schema = "sporespore_r10ab_recovery_replay_receipt_v1"
		if schedule.get("walking_policy_id") == WalkingPolicy.R10AA.ID:
			result.worker_selection.worker = "res://sdk/adapters/godot/gdscript/r10aa_development_worker_v1.gd"
			result.reader = "res://sdk/trace_analysis/r10aa_recovery_replay.gd"
			result.input_schema = "sporespore_r10aa_recovery_replay_input_v1"
			result.report_input_schema = "sporespore_r10aa_recovery_report_replay_input_v1"
			result.retention_schema = "sporespore_r10aa_recovery_entry_retention_v1"
			result.replay_receipt_schema = "sporespore_r10aa_recovery_replay_receipt_v1"
		if schedule.get("walking_policy_id") == WalkingPolicy.R10Z.ID:
			result.worker_selection.worker = "res://sdk/adapters/godot/gdscript/r10z_development_worker_v1.gd"
			result.reader = "res://sdk/trace_analysis/r10z_recovery_replay.gd"
			result.input_schema = "sporespore_r10z_recovery_replay_input_v1"
			result.report_input_schema = "sporespore_r10z_recovery_report_replay_input_v1"
			result.retention_schema = "sporespore_r10z_recovery_entry_retention_v1"
			result.replay_receipt_schema = "sporespore_r10z_recovery_replay_receipt_v1"
		if schedule.get("walking_policy_id") == WalkingPolicy.R10Y.ID:
			result.worker_selection.worker = "res://sdk/adapters/godot/gdscript/r10y_development_worker_v1.gd"
			result.reader = "res://sdk/trace_analysis/r10y_recovery_replay.gd"
			result.input_schema = "sporespore_r10y_recovery_replay_input_v1"
			result.report_input_schema = "sporespore_r10y_recovery_report_replay_input_v1"
			result.retention_schema = "sporespore_r10y_recovery_entry_retention_v1"
			result.replay_receipt_schema = "sporespore_r10y_recovery_replay_receipt_v1"
		if schedule.get("walking_policy_id") == WalkingPolicy.R10V.ID:
			result.worker_selection.worker = "res://sdk/adapters/godot/gdscript/r10v_recovery_worker_v1.gd"
			result.reader = "res://sdk/trace_analysis/r10v_recovery_replay.gd"
			result.input_schema = "sporespore_r10v_recovery_replay_input_v1"
			result.report_input_schema = "sporespore_r10v_recovery_report_replay_input_v1"
			result.retention_schema = "sporespore_r10v_recovery_entry_retention_v1"
			result.replay_receipt_schema = "sporespore_r10v_recovery_replay_receipt_v1"
		if schedule.get("walking_policy_id") == WalkingPolicy.R10U.ID:
			result.worker_selection.worker = "res://sdk/adapters/godot/gdscript/r10u_recovery_worker_v1.gd"
			result.reader = "res://sdk/trace_analysis/r10u_recovery_replay.gd"
			result.input_schema = "sporespore_r10u_recovery_replay_input_v1"
			result.report_input_schema = "sporespore_r10u_recovery_report_replay_input_v1"
			result.retention_schema = "sporespore_r10u_recovery_entry_retention_v1"
			result.replay_receipt_schema = "sporespore_r10u_recovery_replay_receipt_v1"
		if schedule.get("walking_policy_id") == WalkingPolicy.R10T.ID:
			result.worker_selection.worker = "res://sdk/adapters/godot/gdscript/r10t_recovery_worker_v1.gd"
			result.reader = "res://sdk/trace_analysis/r10t_recovery_replay.gd"
			result.input_schema = "sporespore_r10t_recovery_replay_input_v1"
			result.report_input_schema = "sporespore_r10t_recovery_report_replay_input_v1"
			result.retention_schema = "sporespore_r10t_recovery_entry_retention_v1"
			result.replay_receipt_schema = "sporespore_r10t_recovery_replay_receipt_v1"
		if schedule.get("walking_policy_id") == WalkingPolicy.R10S.ID:
			result.worker_selection.worker = "res://sdk/adapters/godot/gdscript/r10s_recovery_worker_v1.gd"
			result.reader = "res://sdk/trace_analysis/r10s_recovery_replay.gd"
			result.input_schema = "sporespore_r10s_recovery_replay_input_v1"
			result.report_input_schema = "sporespore_r10s_recovery_report_replay_input_v1"
			result.retention_schema = "sporespore_r10s_recovery_entry_retention_v1"
			result.replay_receipt_schema = "sporespore_r10s_recovery_replay_receipt_v1"
		if schedule.get("walking_policy_id") == WalkingPolicy.R10R.ID:
			result.worker_selection.worker = "res://sdk/adapters/godot/gdscript/r10r_recovery_worker_v1.gd"
			result.reader = "res://sdk/trace_analysis/r10r_recovery_replay.gd"
			result.input_schema = "sporespore_r10r_recovery_replay_input_v1"
			result.report_input_schema = "sporespore_r10r_recovery_report_replay_input_v1"
			result.retention_schema = "sporespore_r10r_recovery_entry_retention_v1"
			result.replay_receipt_schema = "sporespore_r10r_recovery_replay_receipt_v1"
		if schedule.get("walking_policy_id") == WalkingPolicy.R10Q.ID:
			result.worker_selection.worker = "res://sdk/adapters/godot/gdscript/r10q_recovery_worker_v1.gd"
			result.reader = "res://sdk/trace_analysis/r10q_recovery_replay.gd"
			result.input_schema = "sporespore_r10q_recovery_replay_input_v1"
			result.report_input_schema = "sporespore_r10q_recovery_report_replay_input_v1"
			result.retention_schema = "sporespore_r10q_recovery_entry_retention_v1"
			result.replay_receipt_schema = "sporespore_r10q_recovery_replay_receipt_v1"
	if value.candidate_id == "r10ap-progressive-headroom-v1":
		var seed_guard := preload("res://sdk/adapters/godot/gdscript/r10ap_development_seed_v1.gd")
		if reference != {"resource": seed_guard.PROFILE, "raw_sha256": seed_guard.PROFILE_SHA}: return {}
		result.diagnostic_reader_requires_declaration = true
	if value.candidate_id == "r10am-support-anchored-v1":
		var seed_guard := preload("res://sdk/adapters/godot/gdscript/r10am_development_seed_v1.gd")
		if reference != {"resource": seed_guard.PROFILE, "raw_sha256": seed_guard.PROFILE_SHA}: return {}
		result.diagnostic_reader_requires_declaration = true
	if value.candidate_id == "r10aj-hip-recenter-v1":
		var seed_guard := preload("res://sdk/adapters/godot/gdscript/r10aj_development_seed_v1.gd")
		if reference != {"resource": seed_guard.PROFILE, "raw_sha256": seed_guard.PROFILE_SHA}: return {}
		result.diagnostic_reader_requires_declaration = true
	if value.candidate_id == "r10ai-concurrent-load-rise-v1":
		var seed_guard := preload("res://sdk/adapters/godot/gdscript/r10ai_development_seed_v1.gd")
		if reference != {"resource": seed_guard.PROFILE, "raw_sha256": seed_guard.PROFILE_SHA}: return {}
		result.diagnostic_reader_requires_declaration = true
	if value.candidate_id == "r10ag-detection-frame-load-seeking-v1":
		var seed_guard := preload("res://sdk/adapters/godot/gdscript/r10ag_development_seed_v1.gd")
		if reference != {"resource": seed_guard.PROFILE, "raw_sha256": seed_guard.PROFILE_SHA}: return {}
		result.diagnostic_reader_requires_declaration = true
	if value.candidate_id == "r10af-detection-frame-recovery-v1":
		var capture_selection := preload("res://sdk/adapters/godot/gdscript/r10af_capture_selection_v1.gd")
		if reference != {"resource": capture_selection.Seed.PROFILE, "raw_sha256": capture_selection.Seed.PROFILE_SHA} or capture_selection.native_schedule_v1(result.diagnostic_schedule).is_empty(): return {}
		result.worker_selection.worker = "res://sdk/adapters/godot/gdscript/r10af_development_worker_v1.gd"
		result.reader = "res://sdk/trace_analysis/r10af_recovery_replay.gd"
		result.diagnostic_reader_requires_declaration = true
	if value.candidate_id == "r10ae-contact-frame-diagnostic-v1":
		var capture_selection := preload("res://sdk/adapters/godot/gdscript/r10ae_capture_selection_v1.gd")
		if reference != {"resource": capture_selection.Seed.PROFILE, "raw_sha256": capture_selection.Seed.PROFILE_SHA} or capture_selection.native_schedule_v1(result.diagnostic_schedule).is_empty(): return {}
		result.worker_selection.worker = "res://sdk/adapters/godot/gdscript/r10ae_development_worker_v1.gd"
		result.reader = "res://sdk/trace_analysis/r10ae_recovery_replay.gd"
		result.diagnostic_reader_requires_declaration = true
	if value.candidate_id == "r10ad-contact-frame-diagnostic-v1":
		var capture_selection := preload("res://sdk/adapters/godot/gdscript/r10ad_capture_selection_v1.gd")
		if reference != {"resource": capture_selection.Seed.PROFILE, "raw_sha256": capture_selection.Seed.PROFILE_SHA} or capture_selection.native_schedule_v1(result.diagnostic_schedule).is_empty(): return {}
		result.worker_selection.worker = "res://sdk/adapters/godot/gdscript/r10ad_development_worker_v1.gd"
		result.reader = "res://sdk/trace_analysis/r10ad_recovery_replay.gd"
		result.diagnostic_reader_requires_declaration = true
	if value.candidate_id == "r10ac-contact-frame-diagnostic-v2":
		var capture_selection := preload("res://sdk/adapters/godot/gdscript/r10ac_capture_selection_v1.gd")
		if reference != {"resource": capture_selection.Seed.PROFILE, "raw_sha256": capture_selection.Seed.PROFILE_SHA} or capture_selection.native_schedule_v1(result.diagnostic_schedule).is_empty(): return {}
		result.worker_selection.worker = "res://sdk/adapters/godot/gdscript/r10ac_development_worker_v1.gd"
		result.reader = "res://sdk/trace_analysis/r10ac_recovery_replay.gd"
		result.diagnostic_reader_requires_declaration = true
	return result

static func walking_replay_selection_valid_v1(schedule: Dictionary) -> bool:
	var selected: Variant = schedule.get("walking_replay_profile_id", "")
	if not (selected is String):
		return false
	if selected.is_empty():
		return true
	return (selected == _walking_replay_contract["profile_id"]
		and WalkingEntry.Startup.phase_family_id_v1(schedule.get("walking_entry_profile_id")) == _walking_replay_contract["walking_entry_profile_id"]
		and "sha256:" + FileAccess.get_sha256("res://" + _walking_replay_contract["transition_contract"]) == _walking_replay_contract["transition_contract_sha256"]
		and WalkingEntry.MemoryTransition.selection_valid_v1(_walking_replay_contract["memory_transition_profile_id"], schedule["walking_entry_profile_id"]))

static func walking_memory_transition_id_v1(selection: Dictionary) -> String:
	# load_v1 has checked the exact selector and adapter dependency before use.
	return (_walking_replay_contract["memory_transition_profile_id"]
		if not String(selection.get("diagnostic_schedule", {}).get("walking_replay_profile_id", "")).is_empty() else "")

static func walking_frame_id_v1(selection: Dictionary, segment_id: String) -> String:
	return (selection.get("diagnostic_schedule", {}).get("walking_resume_frame_id", "")
		if WalkingPolicy.FiniteRoute.segment_selected_v1(selection.get("diagnostic_schedule", {}).get("walking_policy_id", ""), segment_id) else "")

static func walking_entry_id_v1(selection: Dictionary, segment_id: String) -> String:
	return (selection.get("diagnostic_schedule", {}).get("walking_entry_profile_id", "")
		if WalkingPolicy.FiniteRoute.segment_selected_v1(selection.get("diagnostic_schedule", {}).get("walking_policy_id", ""), segment_id) else "")

static func walking_start_id_v1(selection: Dictionary, segment_id: String) -> String:
	return (selection.get("diagnostic_schedule", {}).get("walking_start_profile_id", "")
		if WalkingPolicy.FiniteRoute.segment_selected_v1(selection.get("diagnostic_schedule", {}).get("walking_policy_id", ""), segment_id) else "")

static func walking_contact_id_v1(selection: Dictionary, segment_id: String) -> String:
	return (selection.get("diagnostic_schedule", {}).get("walking_contact_profile_id", "")
		if segment_id in WalkingContacts._contract["segments"] else "")

static func limits_v1(selection: Dictionary) -> Dictionary:
	var result: Dictionary = selection.get("diagnostic_schedule", {}).get("limits", DEFAULT_LIMITS).duplicate(true)
	# JSON.parse_string yields binary64 numbers; load_v1 already proved exact
	# integrality. Project these declared counts to the worker/reader integer
	# protocol once, without normalizing any retained observation or old record.
	for key in result:
		result[key] = int(result[key])
	return result

static func diagnostic_walking_limit_valid_v1(maximum_steps: int) -> bool:
	# Historical development profiles keep their original finite bounds. Named
	# successors come from the same schedule source as worker and reader, never
	# from an arbitrary caller-supplied extension of the diagnostic horizon.
	if maximum_steps in [30, 60, int(DEFAULT_LIMITS["after_interaction_steps"])]:
		return true
	var paths := [SCHEDULES_PATH]
	# Named successors have their own immutable schedule file. The profile
	# loader already binds the selected file's hash and passes its exact bound.
	# Include those declarations here too; never add a free-form numeric bypass.
	const DIRECTORY := "res://sdk/development/recovery_schedules/"
	for file in DirAccess.get_files_at(DIRECTORY):
		if file.ends_with(".json"):
			paths.append(DIRECTORY + file)
	for path in paths:
		var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not (source is Dictionary) or not (source.get("schedules") is Dictionary):
			return false
		for schedule in source["schedules"].values():
			if (schedule is Dictionary and typeof(schedule.get("physical_acceptance_authority")) == TYPE_BOOL
				and schedule["physical_acceptance_authority"] == false
				and typeof(schedule.get("release_authority")) == TYPE_BOOL and schedule["release_authority"] == false
				and schedule.get("limits") is Dictionary):
				var bound: Variant = schedule["limits"].get("after_interaction_steps")
				if typeof(bound) in [TYPE_INT, TYPE_FLOAT] and is_finite(bound) and bound == maximum_steps and bound > 480 and bound <= 4096:
					return true
	return false

static func roles_valid_v1(declaration: Dictionary) -> bool:
	var mode: Variant = declaration.get("development_execution_mode")
	if (not (mode is String) or mode not in [_contract["single_mode"], _contract["paired_mode"]]
		or typeof(declaration.get("comparative_authority")) != TYPE_BOOL or declaration["comparative_authority"] != false
		or typeof(declaration.get("baseline_reused")) != TYPE_BOOL or declaration["baseline_reused"] != false
		or not (declaration.get("children") is Array)):
		return false
	var roles := ([_contract["single_role"]] if mode == _contract["single_mode"]
		else ["matched_no_kick_continuation", _contract["single_role"]])
	if roles.size() != declaration["children"].size():
		return false
	for index in range(roles.size()):
		var child: Variant = declaration["children"][index]
		if not (child is Dictionary) or not (child.get("role") is String) or child["role"] != roles[index]:
			return false
	return true
