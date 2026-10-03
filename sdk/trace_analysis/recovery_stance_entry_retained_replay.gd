extends "res://sdk/trace_analysis/development_recovery_candidate_replay.gd"
## Separate post-exposure consumer. Original source and reports stay immutable.
## The exact three reader corrections are applied to hash-pinned script text in
## memory. Retain both transformed hashes, then run the complete original reader.
const ENTRY_PATH := "res://sdk/adapters/godot/gdscript/recovery_stance_entry_replay_v1.gd"
const FULL_PATH := "res://sdk/adapters/godot/gdscript/development_passive_entry_replay_v1.gd"
const ENTRY_SHA := "e93e3a671009ff1f9b9f44afc0e8b726eb33cddb6dab05c9182c247a1d0645a6"
const FULL_SHA := "ad15f8c40c4aae5d57c0bb550166a75bdc71e78c5372e52b7fedd27fa6fb2788"

func _dispatch(sdk: Object, input: Dictionary, binding: Dictionary) -> Dictionary:
	if FileAccess.get_sha256(ENTRY_PATH) != ENTRY_SHA or FileAccess.get_sha256(FULL_PATH) != FULL_SHA:
		return {"ok": false, "failure_code": "R10H_RETAINED_READER_SOURCE_DRIFT"}
	var source := FileAccess.get_file_as_string(ENTRY_PATH)
	var compile_before := "sdk.compile_bounded_quadruped_json(Transport.stringify(descriptor))"
	var session_before := "if session.get(\"evaluation_segment_id\") == Route.SEGMENT: neutral_sessions.append(session)"
	if source.count(compile_before) != 1 or source.count(session_before) != 1:
		return {"ok": false, "failure_code": "R10H_RETAINED_READER_PATCH_SITE"}
	# Reproduce the actual producer's descriptor transport, without tolerance.
	source = source.replace(compile_before, "sdk.compile_bounded_quadruped_json(JSON.stringify(descriptor))")
	# The producer stores handoffs in the arm-level population. Bind its one
	# matching original receipt into a local session view; do not edit the report.
	var session_after := """if session.get("evaluation_segment_id") == Route.SEGMENT:
			var local_session: Dictionary = session.duplicate(true)
			var matches := []
			for handoff in arm.get("walking_actuation_handoff_receipts", []):
				if handoff.get("walking_session_id") == session.get("session_id"): matches.append(handoff)
			if matches.size() != 1: return _failure("RETAINED_HANDOFF_POPULATION")
			local_session["walking_actuation_handoff_receipt"] = matches[0]
			neutral_sessions.append(local_session)"""
	source = source.replace(session_before, session_after)
	var phase_before := "transition.get(\"advance\", {}).get(\"next_phase\") == \"walking_resume\" and transition.get(\"event\", {}).get(\"source_phase\") != \"walking_resume\""
	if source.count(phase_before) != 1: return {"ok": false, "failure_code": "R10H_RETAINED_PHASE_SITE"}
	source = source.replace(phase_before, phase_before.replace("\"walking_resume\"", "\"fresh_selected_policy_walking_resume\""))
	var entry := GDScript.new()
	entry.source_code = source
	if entry.reload() != OK: return {"ok": false, "failure_code": "R10H_RETAINED_ENTRY_COMPILE"}
	var full_source := FileAccess.get_file_as_string(FULL_PATH)
	var dispatch_before := "const StanceEntryReplay := preload(\""+ENTRY_PATH+"\")"
	if full_source.count(dispatch_before) != 1: return {"ok": false, "failure_code": "R10H_RETAINED_DISPATCH_SITE"}
	full_source = full_source.replace(dispatch_before, "static var StanceEntryReplay: GDScript")
	full_source = full_source.replace("var stance_entry_replay := StanceEntryReplay.validate_report_v1", "var stance_entry_replay: Dictionary = StanceEntryReplay.validate_report_v1")
	var full := GDScript.new()
	full.source_code = full_source
	if full.reload() != OK: return {"ok": false, "failure_code": "R10H_RETAINED_FULL_COMPILE"}
	full.StanceEntryReplay = entry
	var result: Dictionary = full.replay_report_v1(sdk, input, binding,
		_candidate_selection.post_kick_controller_id, _candidate_selection,
		CandidateProfile.walking_memory_transition_id_v1(_candidate_selection))
	result["post_exposure_reader"] = {"profile_id": "r10h_original_transport_handoff_and_resume_phase_v2",
		"original_entry_source_sha256": "sha256:"+ENTRY_SHA, "original_full_source_sha256": "sha256:"+FULL_SHA,
		"entry_transform_sha256": "sha256:"+source.sha256_text(), "full_transform_sha256": "sha256:"+full_source.sha256_text(),
		"original_attempt_reclassified": false, "readiness_tolerance_added": false,
		"original_source_edited": false, "original_report_edited": false}
	return result
