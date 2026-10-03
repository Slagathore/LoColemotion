extends SceneTree

const TraceStoreScript := preload("res://scripts/lab/trace_store.gd")
const BundleValidatorScript := preload("res://scripts/lab/run_bundle_validator.gd")
const FailureCodesScript := preload("res://scripts/lab/failure_codes.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const HASH := "sha256:0000000000000000000000000000000000000000000000000000000000000000"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab run-bundle validator tests ===")
	_test_valid_bundle_and_tamper_detection()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_valid_bundle_and_tamper_detection() -> void:
	print("- validator separates structural validity from promotion and detects altered streams")
	var root := _unique_root()
	var run_id := "bundle_validator"
	var manifest := _manifest(run_id)
	var store = TraceStoreScript.new()
	var started: Dictionary = store.start(root, run_id, manifest)
	_check(started["ok"], "bundle reservation succeeds")
	if not started["ok"]:
		_remove_tree(root)
		return
	_check(store.append_frame(_core_frame(0, 0.0))["ok"], "frame 0 records")
	_check(store.append_frame(_core_frame(1, 1.0 / 60.0))["ok"], "frame 1 records")
	_check(store.append_runtime_note({
		"note_sequence": 0,
		"frame_id": null,
		"source": "test_lab_run_bundle_validator",
		"severity": "info",
		"code": "TEST_NOTE",
		"message": "Validator fixture ready.",
		"evidence": {},
	})["ok"], "runtime note records")
	var command_payload := {
		"schema": "sporespore.lab.command.v1",
		"run_id": run_id,
		"command_id": 0,
		"source_frame_id": 0,
		"applied_transition": [0, 1],
		"mode": "TEST",
		"joint_commands": [{
			"joint_id": "joint_0",
			"planned_application_operations": [{
				"operation_id": "op_0",
				"body_id": "body_0",
				"api": "lab.synthetic_noop",
				"arguments": {},
			}],
		}],
		"intervention_operation_ids": [],
	}
	var command_hash := CanonicalJsonScript.sha256(command_payload)
	_check(store.append_command({
		"command_payload_sha256": command_hash,
		"payload": command_payload,
	})["ok"], "sealed synthetic command records")
	_check(store.append_application({
		"schema": "sporespore.lab.application.v1",
		"run_id": run_id,
		"application_sequence": 0,
		"source_kind": "command",
		"source_record_id": "command:0",
		"source_payload_sha256": command_hash,
		"operation_id": "op_0",
		"executor_call_ordinal": 0,
		"api": "lab.synthetic_noop",
		"target_body_id": "body_0",
		"arguments": {},
		"status": "call_returned",
		"failure_code": null,
	})["ok"], "exactly one linked application receipt records")
	var finalized: Dictionary = store.finalize(manifest, _summary(run_id))
	if not finalized["ok"]:
		printerr(finalized)
	_check(finalized["ok"], "fixture bundle finalizes")
	if not finalized["ok"]:
		_remove_tree(root)
		return

	var bundle_path := String(finalized["bundle_path"])
	var valid := BundleValidatorScript.validate_bundle(bundle_path)
	if not valid["ok"]:
		printerr(valid)
	_check(valid["ok"], "sealed bundle passes schemas, hashes, counts, and links")
	_check(valid["can_finalize"], "structurally valid evidence can finalize")
	_check(
		not valid["can_promote"] and not valid["promotion_blockers"].is_empty(),
		"dirty development evidence is valid but cannot promote")
	_check(
		int(valid["stats"]["record_counts"]["frames.jsonl"]) == 2
			and int(valid["stats"]["record_counts"]["runtime_notes.jsonl"]) == 1
			and int(valid["stats"]["record_counts"]["commands.jsonl"]) == 1
			and int(valid["stats"]["record_counts"]["applications.jsonl"]) == 1,
		"validator independently recounts every declared stream")

	var frames_path := bundle_path.path_join("frames.jsonl")
	var frames := TraceStoreScript.read_jsonl(frames_path)
	var append_file := FileAccess.open(frames_path, FileAccess.READ_WRITE)
	append_file.seek_end()
	append_file.store_line(JSON.stringify(frames["records"][1]))
	append_file.flush()
	append_file = null
	var tampered := BundleValidatorScript.validate_bundle(bundle_path)
	_check(not tampered["ok"], "post-seal stream mutation invalidates bundle")
	_check(
		_has_code(tampered["errors"], FailureCodesScript.CHECKSUM_MISMATCH),
		"tamper is named CHECKSUM_MISMATCH")
	_check(
		_has_code(tampered["errors"], FailureCodesScript.LINE_COUNT_MISMATCH),
		"extra record is independently named LINE_COUNT_MISMATCH")
	_check(
		_has_code(tampered["errors"], FailureCodesScript.RECORD_ORDER_INVALID),
		"duplicate terminal frame is independently named RECORD_ORDER_INVALID")

	var applications_path := bundle_path.path_join("applications.jsonl")
	var applications := TraceStoreScript.read_jsonl(applications_path)
	var forged: Dictionary = applications["records"][0].duplicate(true)
	forged["application_sequence"] = 1
	forged["operation_id"] = "forged_op"
	var application_file := FileAccess.open(applications_path, FileAccess.READ_WRITE)
	application_file.seek_end()
	application_file.store_line(JSON.stringify(forged))
	application_file.flush()
	application_file = null
	var link_tampered := BundleValidatorScript.validate_bundle(bundle_path)
	_check(
		_has_code(link_tampered["errors"], FailureCodesScript.APPLICATION_LINK_MISMATCH),
		"receipt for an unsealed operation is named APPLICATION_LINK_MISMATCH")
	_remove_tree(root)


static func _has_code(errors: Array, code: String) -> bool:
	for error_value in errors:
		if String(error_value.get("code", "")) == code:
			return true
	return false


static func _manifest(run_id: String) -> Dictionary:
	return {
		"schema": "sporespore.lab.manifest.v1",
		"run_id": run_id,
		"status": "RUNNING",
		"experiment_id": "L0_BUNDLE_VALIDATOR",
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
			"commands.jsonl",
			"applications.jsonl",
			"runtime_notes.jsonl",
			"summary.json",
		],
	}


static func _summary(run_id: String) -> Dictionary:
	return {
		"schema": "sporespore.lab.summary.v1",
		"run_id": run_id,
		"termination": "completed",
		"evidence_validity": "valid",
		"hypothesis_result": "supported",
		"promotion": "pass",
		"frame_count": 2,
		"runtime_note_count": 1,
		"first_frame_id": 0,
		"last_frame_id": 1,
		"metrics": [{
			"metric_id": "terminal_x",
			"value": 1.0 / 60.0,
			"unit": "m",
			"availability": "derived",
			"source_stream": "frames.jsonl",
			"source_frame_range": [0, 1],
			"source_field": "/bodies/body_0/transform/origin/0",
			"aggregation_id": "last",
			"aggregation_version": 1,
		}],
	}


static func _core_frame(frame_id: int, time_s: float) -> Dictionary:
	return {
		"schema_version": "frame_v1",
		"frame_id": frame_id,
		"physics_step_id": frame_id,
		"capture_epoch": frame_id,
		"physics_time_s": time_s,
		"sample_phase": "integrate_callback",
		"experiment_phase": "MEASURE",
		"release_frame_id": 0,
		"bodies": {
			"body_0": {
				"physics_step_id": frame_id,
				"body_callback_sequence": frame_id + 1,
				"capture_epoch": frame_id,
				"sample_phase": "integrate_callback",
				"body_id": "body_0",
				"part_index": 0,
				"transform": {
					"basis": [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]],
					"origin": [time_s, 1.0, 0.0],
				},
				"center_of_mass_world": [time_s, 1.0, 0.0],
				"linear_velocity": [1.0, 0.0, 0.0],
				"angular_velocity": [0.0, 0.0, 0.0],
				"mass_kg": 1.0,
				"inverse_inertia_tensor_world": {
					"x": [1.0, 0.0, 0.0],
					"y": [0.0, 1.0, 0.0],
					"z": [0.0, 0.0, 1.0],
				},
				"sleeping": false,
				"finite": true,
				"step_s": 1.0 / 60.0,
				"total_gravity_world": [0.0, 0.0, 0.0],
				"com_frame_oracle_error_m": 0.0,
				"observer_profile_id": "full_state_v1",
				"observer_adapter_id": "rigid_body_integrate_forces_v1",
			},
		},
		"contacts": [],
		"availability": {
			"required_body_ids": ["body_0"],
			"captured_body_count": 1,
			"contact_count": 0,
			"invalid_reasons": [],
			"fields": {
				"body:body_0": {
					"status": "measured",
					"reason": null,
					"source": "rigid_body_integrate_forces_v1",
				},
				"contacts": {
					"status": "measured",
					"reason": null,
					"source": "rigid_body_integrate_forces_v1",
				},
				"frame": {
					"status": "measured",
					"reason": null,
					"source": "sensor_frame_builder_v1",
				},
			},
		},
		"finite": true,
	}


static func _unique_root() -> String:
	return "res://.tmp/lab_bundle_tests/validator_%d_%d" % [
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]


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
