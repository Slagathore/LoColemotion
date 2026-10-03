extends "res://sdk/trace_analysis/development_recovery_candidate_replay.gd"
## Separate post-exposure consumer for the consumed R10J pair. Original source
## and reports stay immutable. The exact one-line reader correction is applied
## to hash-pinned script text in memory: the R10J producer compiles the
## descriptor through the full-precision transport exactly as R10I does, so the
## reader must decode its own compilation the same way. Retain both transformed
## hashes, then run the complete original reader.
const ENTRY_PATH := "res://sdk/adapters/godot/gdscript/recovery_stance_entry_replay_v1.gd"
const FULL_PATH := "res://sdk/adapters/godot/gdscript/development_passive_entry_replay_v1.gd"
const ENTRY_SHA := "ad66ad75dae8377d687a4cb178b54763d24e599b8bc543f74aaebc16baafc9aa"
const FULL_SHA := "ad15f8c40c4aae5d57c0bb550166a75bdc71e78c5372e52b7fedd27fa6fb2788"

func _dispatch(sdk: Object, input: Dictionary, binding: Dictionary) -> Dictionary:
	if FileAccess.get_sha256(ENTRY_PATH) != ENTRY_SHA or FileAccess.get_sha256(FULL_PATH) != FULL_SHA:
		return {"ok": false, "failure_code": "R10J_RETAINED_READER_SOURCE_DRIFT"}
	var source := FileAccess.get_file_as_string(ENTRY_PATH)
	var compile_before := "var compiled_envelope: Variant = sdk.decode_exact_json_v1(compiled_raw) if Route.flexed_selected_v1(selected) else JSON.parse_string(compiled_raw)"
	if source.count(compile_before) != 1:
		return {"ok": false, "failure_code": "R10J_RETAINED_READER_PATCH_SITE"}
	# Decode the reader's own compilation exactly for every ramped route, not only R10I.
	source = source.replace(compile_before, "var compiled_envelope: Variant = sdk.decode_exact_json_v1(compiled_raw) if Route.ramped_selected_v1(selected) else JSON.parse_string(compiled_raw)")
	var decode_before := "var response: Variant = sdk.decode_exact_json_v1(raw) if (flexed or hold) else JSON.parse_string(raw)"
	if source.count(decode_before) != 1:
		return {"ok": false, "failure_code": "R10J_RETAINED_READER_DECODE_SITE"}
	# The production adapter parses V50 responses with the generic parser; the reader must compare the same projection.
	source = source.replace(decode_before, "var response: Variant = sdk.decode_exact_json_v1(raw) if flexed else JSON.parse_string(raw)")
	var ledger_before := "step.get(\"motor_population_readback\", {}), handoff, Route.entry_selection_for_v1(selected))"
	if source.count(ledger_before) != 1:
		return {"ok": false, "failure_code": "R10J_RETAINED_READER_LEDGER_SITE"}
	# Hold rows were produced under the hold alias; recompute their ledger intent under the same identity.
	source = source.replace(ledger_before, "step.get(\"motor_population_readback\", {}), handoff, Route.HOLD_ALIAS if hold else Route.entry_selection_for_v1(selected))")
	var entry := GDScript.new()
	entry.source_code = source
	if entry.reload() != OK: return {"ok": false, "failure_code": "R10J_RETAINED_ENTRY_COMPILE"}
	var full_source := FileAccess.get_file_as_string(FULL_PATH)
	var dispatch_before := "const StanceEntryReplay := preload(\""+ENTRY_PATH+"\")"
	if full_source.count(dispatch_before) != 1: return {"ok": false, "failure_code": "R10J_RETAINED_DISPATCH_SITE"}
	full_source = full_source.replace(dispatch_before, "static var StanceEntryReplay: GDScript")
	full_source = full_source.replace("var stance_entry_replay := StanceEntryReplay.validate_report_v1", "var stance_entry_replay: Dictionary = StanceEntryReplay.validate_report_v1")
	var full := GDScript.new()
	full.source_code = full_source
	if full.reload() != OK: return {"ok": false, "failure_code": "R10J_RETAINED_FULL_COMPILE"}
	full.StanceEntryReplay = entry
	var result: Dictionary = full.replay_report_v1(sdk, input, binding,
		_candidate_selection.post_kick_controller_id, _candidate_selection,
		CandidateProfile.walking_memory_transition_id_v1(_candidate_selection))
	result["post_exposure_reader"] = {"profile_id": "r10j_exact_descriptor_compilation_v1",
		"original_entry_source_sha256": "sha256:"+ENTRY_SHA, "original_full_source_sha256": "sha256:"+FULL_SHA,
		"entry_transform_sha256": "sha256:"+source.sha256_text(), "full_transform_sha256": "sha256:"+full_source.sha256_text(),
		"original_attempt_reclassified": false, "readiness_tolerance_added": false,
		"original_source_edited": false, "original_report_edited": false}
	return result
