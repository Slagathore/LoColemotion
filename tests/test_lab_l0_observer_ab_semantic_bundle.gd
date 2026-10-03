extends SceneTree

const BundleValidatorScript := preload(
	"res://scripts/lab/run_bundle_validator.gd")
const CanonicalJsonScript := preload(
	"res://scripts/lab/canonical_json.gd")
const LabRunnerScript := preload("res://scripts/lab/lab_runner.gd")
const SpecCompilerScript := preload("res://scripts/lab/spec_compiler.gd")
const TraceStoreScript := preload("res://scripts/lab/trace_store.gd")

const RECOMPUTER_ID := (
	"sporespore.lab.l0_observer_ab_metric_recomputer.v1")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab L0.3 observer A/B semantic bundle validation ===")
	var spec_path := (
		"res://data/lab/experiments/L0_3_observer_ab_v1.tres")
	var loaded = ResourceLoader.load(
		spec_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var resource_sha := "sha256:%s" % FileAccess.get_sha256(spec_path)
	var compiled := SpecCompilerScript.compile(
		loaded,
		{},
		{},
		{
			"resource_path": spec_path,
			"resource_sha256": resource_sha,
		})
	_check(bool(compiled.get("ok", false)), "L0.3 experiment compiles")
	if not bool(compiled.get("ok", false)):
		_finish()
		return

	var root := ProjectSettings.globalize_path(
		"res://.tmp/lab_l0_observer_semantic_%d_%d" % [
			OS.get_process_id(),
			Time.get_ticks_usec(),
		]).replace("\\", "/")
	var runner = LabRunnerScript.new()
	var run_result: Dictionary = await runner.run(
		self,
		compiled["experiment"],
		root,
		{
			"resource_path": spec_path,
			"resource_sha256": resource_sha,
		})
	var bundle_path := String(run_result.get("artifacts", ""))
	var completed_development_run: bool = (
		run_result.get("termination") == "completed"
		and int(run_result.get("exit_code", -1)) == 2
		and not bundle_path.is_empty())
	if not completed_development_run:
		printerr("  L0.3 RUN DIAGNOSTIC  ", run_result)
	_check(
		completed_development_run,
		"direct L0.3 run completes as development-only evidence")
	if bundle_path.is_empty() or not DirAccess.dir_exists_absolute(
			bundle_path):
		_remove_tree(root)
		_finish()
		return

	var baseline := BundleValidatorScript.validate_bundle(bundle_path)
	var verifier: Dictionary = baseline.get(
		"stats", {}).get("semantic_verifiers", {}).get(
			RECOMPUTER_ID, {})
	_check(
		bool(baseline.get("ok", false))
			and bool(verifier.get("ok", false)),
		"honest L0.3 bundle passes its independent semantic verifier")
	_check(
		int(verifier.get("verified_metric_count", -1)) == 4
			and int(verifier.get("verified_stream_count", -1)) == 4,
		"verifier proves all four metrics from all four frame streams")

	_exercise_metric_deletion(bundle_path)
	_exercise_attacker_selected_provenance(bundle_path)
	_exercise_summary_conclusion_forgery(bundle_path)
	_exercise_observer_profile_forgery(bundle_path)
	_exercise_primary_contact_divergence(bundle_path)
	_exercise_control_ledger_forgery(bundle_path)
	_exercise_reporting_mirror_forgery(bundle_path)

	_remove_tree(root)
	_finish()


func _exercise_metric_deletion(bundle_path: String) -> void:
	var summary_path := bundle_path.path_join("summary.json")
	var original := _read_json(summary_path)
	var forged: Dictionary = original.duplicate(true)
	forged["metrics"] = []
	var resealed := (
		_write_json(summary_path, forged)
		and _rebuild_checksums(
			bundle_path, String(forged.get("run_id", ""))))
	var validation := (
		BundleValidatorScript.validate_bundle(bundle_path)
		if resealed
		else {})
	_check(
		resealed
			and not bool(validation.get("ok", true))
			and _has_semantic_error(
				validation.get("errors", []),
				"METRIC_SET_MISMATCH"),
		"deleting every L0.3 metric and resealing cannot erase the gate")
	_restore_json(bundle_path, summary_path, original)


func _exercise_attacker_selected_provenance(
		bundle_path: String) -> void:
	var summary_path := bundle_path.path_join("summary.json")
	var original := _read_json(summary_path)
	var forged: Dictionary = original.duplicate(true)
	var metric_index := _metric_index(
		forged, "max_position_delta_m")
	var prepared := metric_index >= 0
	if prepared:
		var left_operand: Dictionary = forged[
			"metrics"][metric_index]["source_operands"][0].duplicate(true)
		forged["metrics"][metric_index]["source_operands"] = [
			left_operand,
			left_operand.duplicate(true),
		]
		forged["metrics"][metric_index]["value"] = 0.0
		forged["metrics"][metric_index][
			"recompute_absolute_tolerance"] = 1000000.0
	var resealed := (
		prepared
		and _write_json(summary_path, forged)
		and _rebuild_checksums(
			bundle_path, String(forged.get("run_id", ""))))
	var validation := (
		BundleValidatorScript.validate_bundle(bundle_path)
		if resealed
		else {})
	_check(
		resealed
			and not bool(validation.get("ok", true))
			and (
				_has_semantic_error(
					validation.get("errors", []),
					"METRIC_OPERAND_CONTRACT_MISMATCH")
				or _has_semantic_error(
					validation.get("errors", []),
					"METRIC_CONTRACT_MISMATCH")
			),
		"self-comparison and attacker-selected tolerance cannot replace preregistration")
	_restore_json(bundle_path, summary_path, original)


func _exercise_summary_conclusion_forgery(
		bundle_path: String) -> void:
	var summary_path := bundle_path.path_join("summary.json")
	var original := _read_json(summary_path)
	var forged: Dictionary = original.duplicate(true)
	var physical: Dictionary = forged[
		"gate_results"]["physical"].duplicate(true)
	physical["pass"] = not bool(physical.get("pass", false))
	physical["reason"] = (
		null
		if bool(physical["pass"])
		else "ANALYTIC_TOLERANCE_EXCEEDED")
	forged["gate_results"]["physical"] = physical
	forged["hypothesis_result"] = (
		"contradicted"
		if String(original.get("hypothesis_result", ""))
			== "supported"
		else "supported")
	forged["promotion"] = "fail"
	var resealed := (
		_write_json(summary_path, forged)
		and _rebuild_checksums(
			bundle_path, String(forged.get("run_id", ""))))
	var validation := (
		BundleValidatorScript.validate_bundle(bundle_path)
		if resealed
		else {})
	_check(
		resealed
			and not bool(validation.get("ok", true))
			and _has_semantic_error(
				validation.get("errors", []),
				"PHYSICAL_GATE_RESULT_MISMATCH")
			and _has_semantic_error(
				validation.get("errors", []),
				"SUMMARY_HYPOTHESIS_RESULT_MISMATCH")
			and _has_semantic_error(
				validation.get("errors", []),
				"SUMMARY_PROMOTION_MISMATCH"),
		"physical gate, hypothesis, and promotion are rebuilt instead of trusted")
	_restore_json(bundle_path, summary_path, original)


func _exercise_observer_profile_forgery(
		bundle_path: String) -> void:
	var stream_path := bundle_path.path_join(
		"observer_minimal_frames.jsonl")
	var original := _read_jsonl(stream_path)
	var forged: Array = original.duplicate(true)
	var prepared := not forged.is_empty()
	if prepared:
		forged[0]["bodies"]["body_0"]["observer_profile_id"] = (
			"full_state_v1")
	var resealed := (
		prepared
		and _write_jsonl(stream_path, forged)
		and _rebuild_checksums(
			bundle_path, String(forged[0].get("run_id", ""))))
	var validation := (
		BundleValidatorScript.validate_bundle(bundle_path)
		if resealed
		else {})
	_check(
		resealed
			and not bool(validation.get("ok", true))
			and _has_semantic_error(
				validation.get("errors", []),
				"OBSERVER_ARM_IDENTITY_MISMATCH"),
		"resealed observer stream cannot impersonate another profile")
	_restore_jsonl(bundle_path, stream_path, original)


func _exercise_primary_contact_divergence(
		bundle_path: String) -> void:
	var stream_path := bundle_path.path_join("frames.jsonl")
	var original := _read_jsonl(stream_path)
	var forged: Array = original.duplicate(true)
	var prepared := not forged.is_empty()
	if prepared:
		forged[0]["physics_time_s"] = (
			float(forged[0]["physics_time_s"]) + 0.001)
	var resealed := (
		prepared
		and _write_jsonl(stream_path, forged)
		and _rebuild_checksums(
			bundle_path, String(forged[0].get("run_id", ""))))
	var validation := (
		BundleValidatorScript.validate_bundle(bundle_path)
		if resealed
		else {})
	if (
		not resealed
		or bool(validation.get("ok", true))
		or not _has_semantic_error(
			validation.get("errors", []),
			"PRIMARY_CONTACT_STREAM_MISMATCH")
	):
		printerr(
			"  PRIMARY-CONTACT DIAGNOSTIC  resealed=",
			resealed,
			" validation=",
			validation)
	_check(
		resealed
			and not bool(validation.get("ok", true))
			and _has_semantic_error(
				validation.get("errors", []),
				"PRIMARY_CONTACT_STREAM_MISMATCH"),
		"primary trajectory cannot diverge from its declared contact arm")
	_restore_jsonl(bundle_path, stream_path, original)


func _exercise_control_ledger_forgery(
		bundle_path: String) -> void:
	var stream_path := bundle_path.path_join("commands.jsonl")
	var original := _read_jsonl(stream_path)
	var forged: Array = original.duplicate(true)
	var prepared := not forged.is_empty()
	if prepared:
		forged[0]["payload"]["mode"] = "FORGED_CONTROL"
		forged[0]["command_payload_sha256"] = (
			CanonicalJsonScript.sha256(forged[0]["payload"]))
	var resealed := (
		prepared
		and _write_jsonl(stream_path, forged)
		and _rebuild_checksums(
			bundle_path,
			String(forged[0]["payload"].get("run_id", ""))))
	var validation := (
		BundleValidatorScript.validate_bundle(bundle_path)
		if resealed
		else {})
	_check(
		resealed
			and not bool(validation.get("ok", true))
			and _has_semantic_error(
				validation.get("errors", []),
				"NO_CONTROL_COMMAND_MISMATCH"),
		"observer-only L0.3 bundle cannot acquire a resealed control command")
	_restore_jsonl(bundle_path, stream_path, original)


func _exercise_reporting_mirror_forgery(
		bundle_path: String) -> void:
	var event_path := bundle_path.path_join("events.jsonl")
	var note_path := bundle_path.path_join("runtime_notes.jsonl")
	var original_events := _read_jsonl(event_path)
	var original_notes := _read_jsonl(note_path)
	var forged_events: Array = original_events.duplicate(true)
	var forged_notes: Array = original_notes.duplicate(true)
	var prepared := (
		forged_events.size() == 1
		and forged_notes.size() == 2)
	if prepared:
		forged_events[0]["evidence"]["physical_gate_pass"] = not bool(
			forged_events[0]["evidence"]["physical_gate_pass"])
		forged_notes[1]["evidence"]["max_position_delta_m"] = (
			float(forged_notes[1]["evidence"][
				"max_position_delta_m"]) + 0.5)
	var run_id := (
		String(forged_events[0].get("run_id", ""))
		if prepared
		else "")
	var resealed := (
		prepared
		and _write_jsonl(event_path, forged_events)
		and _write_jsonl(note_path, forged_notes)
		and _rebuild_checksums(bundle_path, run_id))
	var validation := (
		BundleValidatorScript.validate_bundle(bundle_path)
		if resealed
		else {})
	_check(
		resealed
			and not bool(validation.get("ok", true))
			and _has_semantic_error(
				validation.get("errors", []),
				"PROMOTION_EVENT_MISMATCH")
			and _has_semantic_error(
				validation.get("errors", []),
				"RUN_RESULT_NOTE_MISMATCH"),
		"events and runtime notes cannot contradict recomputed L0.3 truth")
	var events_restored := _write_jsonl(
		event_path, original_events)
	var notes_restored := _write_jsonl(
		note_path, original_notes)
	var restored := (
		events_restored
		and notes_restored
		and _rebuild_checksums(bundle_path, run_id))
	var restored_validation := (
		BundleValidatorScript.validate_bundle(bundle_path)
		if restored
		else {})
	_check(
		restored and bool(restored_validation.get("ok", false)),
		"bundle restores after reporting-mirror forgery exercise")


func _restore_json(
		bundle_path: String,
		path: String,
		original: Dictionary) -> void:
	var restored := (
		_write_json(path, original)
		and _rebuild_checksums(
			bundle_path, String(original.get("run_id", ""))))
	var validation := (
		BundleValidatorScript.validate_bundle(bundle_path)
		if restored
		else {})
	if not restored or not bool(validation.get("ok", false)):
		printerr(
			"  RESTORE DIAGNOSTIC  path=",
			path,
			" restored=",
			restored,
			" validation=",
			validation)
	_check(
		restored and bool(validation.get("ok", false)),
		"bundle restores after JSON forgery exercise")


func _restore_jsonl(
		bundle_path: String,
		path: String,
		original: Array) -> void:
	var run_id := ""
	if not original.is_empty():
		var first: Dictionary = original[0]
		run_id = String(first.get("run_id", ""))
		if run_id.is_empty() and first.get("payload") is Dictionary:
			run_id = String(
				(first["payload"] as Dictionary).get("run_id", ""))
	var restored := (
		_write_jsonl(path, original)
		and _rebuild_checksums(bundle_path, run_id))
	var validation := (
		BundleValidatorScript.validate_bundle(bundle_path)
		if restored
		else {})
	if not restored or not bool(validation.get("ok", false)):
		printerr(
			"  JSONL RESTORE DIAGNOSTIC  path=",
			path,
			" restored=",
			restored,
			" validation=",
			validation)
	_check(
		restored and bool(validation.get("ok", false)),
		"bundle restores after observer-stream forgery exercise")


static func _rebuild_checksums(
		bundle_path: String,
		run_id: String) -> bool:
	var checksums := TraceStoreScript.build_checksums_for_parent(
		bundle_path, run_id)
	return _write_json(
		bundle_path.path_join("checksums.json"), checksums)


static func _write_json(path: String, value: Dictionary) -> bool:
	var result := TraceStoreScript.write_json_for_parent(path, value)
	return bool(result.get("ok", false))


static func _read_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func _read_jsonl(path: String) -> Array:
	var records: Array = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return records
	while file.get_position() < file.get_length():
		var parsed = JSON.parse_string(file.get_line())
		if parsed is Dictionary:
			records.append(parsed)
	return records


static func _write_jsonl(path: String, records: Array) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	for record in records:
		file.store_line(CanonicalJsonScript.stringify(record))
	file.flush()
	var write_error := file.get_error()
	file = null
	return write_error == OK


static func _metric_index(
		summary: Dictionary,
		metric_id: String) -> int:
	for metric_index in summary.get("metrics", []).size():
		if String(summary["metrics"][metric_index].get(
			"metric_id", "")) == metric_id:
			return metric_index
	return -1


static func _has_semantic_error(
		errors: Array,
		semantic_code: String) -> bool:
	for error_value in errors:
		if semantic_code in String(error_value.get("message", "")):
			return true
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


static func _remove_tree(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var directory := DirAccess.open(absolute)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child := absolute.path_join(name)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute)
