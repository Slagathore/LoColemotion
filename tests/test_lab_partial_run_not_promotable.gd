extends SceneTree

const TraceStoreScript := preload("res://scripts/lab/trace_store.gd")
const BundleValidatorScript := preload("res://scripts/lab/run_bundle_validator.gd")
const FailureCodesScript := preload("res://scripts/lab/failure_codes.gd")

const HASH := "sha256:0000000000000000000000000000000000000000000000000000000000000000"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab partial-run promotion tests ===")
	_test_interrupted_bundle_stays_partial()
	_test_failed_finalize_is_an_irreversible_seal()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_interrupted_bundle_stays_partial() -> void:
	print("- interruption preserves inspectable artifacts but cannot promote")
	var root := "res://.tmp/lab_bundle_tests/partial_%d_%d" % [
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]
	var run_id := "interrupted_run"
	var store = TraceStoreScript.new()
	var started: Dictionary = store.start(root, run_id, _manifest(run_id))
	_check(started["ok"], "partial reservation succeeds")
	if not started["ok"]:
		_remove_tree(root)
		return
	var left: Dictionary = store.leave_partial()
	_check(left["ok"], "controlled interruption leaves partial evidence")
	var partial_path := String(left["partial_path"])
	_check(
		DirAccess.dir_exists_absolute(partial_path)
			and FileAccess.file_exists(partial_path.path_join("manifest.json")),
		"partial directory and running manifest remain inspectable")
	var validation := BundleValidatorScript.validate_bundle(partial_path)
	_check(not validation["ok"], "default validation rejects a partial directory")
	_check(
		not validation["can_finalize"] and not validation["can_promote"],
		"partial run cannot finalize or promote")
	var found_partial_code := false
	for error_value in validation["errors"]:
		if String(error_value.get("code", "")) == FailureCodesScript.PARTIAL_RUN_NOT_PROMOTABLE:
			found_partial_code = true
			break
	_check(found_partial_code, "rejection names PARTIAL_RUN_NOT_PROMOTABLE")
	var inspection := BundleValidatorScript.validate_bundle(
		partial_path, {"allow_partial": true})
	_check(
		inspection["is_partial"] and not inspection["can_promote"],
		"inspection mode never upgrades a partial run")
	_remove_tree(root)


func _test_failed_finalize_is_an_irreversible_seal() -> void:
	print("- a failed final validation cannot reopen immutable streams")
	var root := "res://.tmp/lab_bundle_tests/seal_%d_%d" % [
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]
	var run_id := "failed_finalize"
	var manifest := _manifest(run_id)
	var store = TraceStoreScript.new()
	var started: Dictionary = store.start(root, run_id, manifest)
	_check(started["ok"], "failed-finalize fixture reserves")
	if not started["ok"]:
		_remove_tree(root)
		return
	_check(store.append_runtime_note({
		"note_sequence": 0,
		"frame_id": null,
		"source": "test_lab_partial_run_not_promotable",
		"severity": "error",
		"code": "FINALIZE_FIXTURE",
		"message": "Deliberately mismatched summary count.",
		"evidence": {},
	})["ok"], "pre-seal note records")
	var failed_finalize: Dictionary = store.finalize(manifest, {
		"schema": "sporespore.lab.summary.v1",
		"run_id": run_id,
		"termination": "aborted",
		"evidence_validity": "invalid",
		"hypothesis_result": "inconclusive",
		"promotion": "not_evaluated",
		"frame_count": 0,
		"runtime_note_count": 2,
		"first_frame_id": null,
		"last_frame_id": null,
		"metrics": [],
	})
	_check(not failed_finalize["ok"], "count-mismatched bundle fails final validation")
	var late_append: Dictionary = store.append_runtime_note({
		"note_sequence": 1,
		"frame_id": null,
		"source": "test_lab_partial_run_not_promotable",
		"severity": "warning",
		"code": "ILLEGAL_LATE_NOTE",
		"message": "This record must never be appended.",
		"evidence": {},
	})
	_check(not late_append["ok"], "failed finalize does not reopen append authority")
	_check(
		DirAccess.dir_exists_absolute(String(started["partial_path"])),
		"failed sealed bundle remains .partial for inspection")
	store.leave_partial()
	_remove_tree(root)


static func _manifest(run_id: String) -> Dictionary:
	return {
		"schema": "sporespore.lab.manifest.v1",
		"run_id": run_id,
		"status": "RUNNING",
		"experiment_id": "L0_INTERRUPTION_TEST",
		"schema_set": "sporespore.lab.schemas.v1",
		"recorder_version": "flight-recorder-v1",
		"expanded_spec_sha256": HASH,
		"dirty_worktree": true,
		"execution_mode": "development",
		"reproducibility": "partial_dirty_source",
		"units": "SI",
		"started_utc": "2026-07-19T00:00:00Z",
		"required_artifacts": [
			"manifest.json",
			"frames.jsonl",
			"runtime_notes.jsonl",
			"summary.json",
		],
	}


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
