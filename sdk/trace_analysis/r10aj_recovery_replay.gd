extends "res://sdk/trace_analysis/development_passive_entry_replay.gd"
## Explicit report/profile/hash/declaration inputs, never inferred from a report.
const CandidateProfile := preload("res://sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd")
const Combined := preload("res://sdk/adapters/godot/gdscript/r10aj_complete_report_replay_v1.gd")
var _candidate_selection: Dictionary = {}
var _declaration: Dictionary = {}

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 4:
		_finish({"ok": false, "failure_code": "R10AJ_REPLAY_ARGUMENTS"}); return
	_candidate_selection = CandidateProfile.load_v1({"resource": args[1], "raw_sha256": args[2]})
	if _candidate_selection.get("candidate_profile") != {"resource": Combined.Seed.PROFILE, "raw_sha256": Combined.Seed.PROFILE_SHA}:
		_finish({"ok": false, "failure_code": "R10AJ_REPLAY_PROFILE"}); return
	var declared: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[3]))
	if not declared is Dictionary:
		_finish({"ok": false, "failure_code": "R10AJ_REPLAY_DECLARATION"}); return
	_declaration = declared
	var runtime := Combined.Controller.Canonical.Route.ProfileCapabilityScript.select_r10aj_diagnostic_runtime_v1(
		_declaration, _candidate_selection.candidate_profile)
	if runtime.get("ok") != true:
		_finish(runtime); return
	super._run()

func _input_arguments_v1() -> PackedStringArray:
	return PackedStringArray([OS.get_cmdline_user_args()[0]])

func _selection_v1() -> Dictionary:
	var worker: Dictionary = _candidate_selection.get("worker_selection", {})
	return {"binding": worker.get("binding", ""), "extension": worker.get("extension", ""),
		"controller_id": _candidate_selection.get("post_kick_controller_id", ""),
		"marker": CandidateProfile.contract_v1()["replay_marker"]}

func _dispatch(sdk: Object, input: Dictionary, binding: Dictionary) -> Dictionary:
	if input.get("schema_version") == _candidate_selection.worker_selection.report_schema:
		return Combined.replay_report_v1(sdk, input, binding, _candidate_selection, _declaration)
	if input.get("schema_version") == _candidate_selection.report_input_schema and input.get("report") is Dictionary:
		return Combined.replay_report_v1(sdk, input.report, binding, _candidate_selection, _declaration)
	return {"ok": false, "failure_code": "R10AJ_COMPLETE_REPORT_REQUIRED"}
