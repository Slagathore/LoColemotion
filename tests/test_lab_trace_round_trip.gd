extends SceneTree

const TraceStoreScript := preload("res://scripts/lab/trace_store.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const HASH := "sha256:0000000000000000000000000000000000000000000000000000000000000000"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab trace round-trip tests ===")
	_test_append_flush_seal_read()
	_test_destination_file_collision_is_rejected()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_append_flush_seal_read() -> void:
	print("- append-only frames survive caller mutation and finalize as one sealed bundle")
	var root := _unique_root("round_trip")
	var run_id := "trace_round_trip"
	var store = TraceStoreScript.new()
	var manifest := _manifest(run_id)
	var started: Dictionary = store.start(root, run_id, manifest)
	_check(started["ok"], "partial bundle is reserved")
	if not started["ok"]:
		_remove_tree(root)
		return
	var unknown_stream: Dictionary = store.append_record(
		"unregistered_stream",
		{"run_id": run_id})
	_check(
		not unknown_stream["ok"] and unknown_stream["code"] == "SCHEMA_INVALID",
		"unregistered JSONL stream is rejected before any bytes are written")

	var frame_0 := _core_frame(0, 0.0)
	var expected_frame_0 := frame_0.duplicate(true)
	var append_0: Dictionary = store.append_frame(frame_0)
	_check(append_0["ok"], "frame 0 appends")
	frame_0["bodies"]["body_0"]["transform"]["origin"][0] = 999.0
	var append_1: Dictionary = store.append_frame(_core_frame(1, 1.0 / 60.0))
	_check(append_1["ok"], "frame 1 appends")
	for observer_stream in [
		"observer_minimal_frames",
		"observer_full_frames",
		"observer_contact_frames",
	]:
		var observer_append: Dictionary = store.append_observer_frame(
			observer_stream, _core_frame(0, 0.0))
		_check(
			observer_append["ok"],
			"%s appends through the typed observer API" % observer_stream)
	var note_result: Dictionary = store.append_runtime_note({
		"note_sequence": 0,
		"frame_id": 1,
		"source": "test_lab_trace_round_trip",
		"severity": "info",
		"code": "TEST_NOTE",
		"message": "Round-trip fixture completed.",
		"evidence": {"frame_count": 2},
	})
	_check(note_result["ok"], "runtime note appends")
	var flush_result: Dictionary = store.flush()
	_check(
		flush_result["ok"] and int(flush_result["line_counts"]["frames"]) == 2,
		"flush reports exact append count")

	var finalized: Dictionary = store.finalize(
		manifest,
		_summary(run_id, 2, 1))
	if not finalized["ok"]:
		printerr(finalized)
	_check(finalized["ok"], "valid partial bundle seals and renames")
	if not finalized["ok"]:
		_remove_tree(root)
		return
	_check(
		finalized["pre_rename_validation"]["is_partial"]
			and not finalized["pre_rename_validation"]["can_promote"],
		"pre-rename validation remains explicitly partial and non-promotable")
	_check(
		not finalized["validation"]["is_partial"]
			and finalized["validation"]["can_finalize"],
		"finalize returns a fresh validation of the completed path")
	var bundle_path := String(finalized["bundle_path"])
	_check(
		DirAccess.dir_exists_absolute(bundle_path)
			and not DirAccess.dir_exists_absolute(String(started["partial_path"])),
		"completed directory exists and .partial directory is gone")

	var frames := TraceStoreScript.read_jsonl(bundle_path.path_join("frames.jsonl"))
	_check(frames["ok"] and frames["records"].size() == 2, "two JSONL frames parse")
	if frames["ok"] and frames["records"].size() == 2:
		var recorded: Dictionary = frames["records"][0]
		_check(
			float(recorded["bodies"]["body_0"]["transform"]["origin"][0])
				== float(expected_frame_0["bodies"]["body_0"]["transform"]["origin"][0]),
			"retained caller mutation cannot alter recorded frame")
		_check(
			String(recorded["schema"]) == "sporespore.lab.frame.v1"
				and String(recorded["run_id"]) == run_id,
			"TraceStore adds the immutable evidence envelope")
		var normalized_expected := expected_frame_0.duplicate(true)
		normalized_expected["schema"] = "sporespore.lab.frame.v1"
		normalized_expected["run_id"] = run_id
		_check(
			CanonicalJsonScript.stringify(recorded)
				== CanonicalJsonScript.stringify(normalized_expected),
			"parsed record round-trips to identical canonical bytes")
	_check(
		FileAccess.file_exists(bundle_path.path_join("checksums.json")),
		"completed bundle contains checksums")
	for observer_artifact in [
		"observer_minimal_frames.jsonl",
		"observer_full_frames.jsonl",
		"observer_contact_frames.jsonl",
	]:
		var observer_frames := TraceStoreScript.read_jsonl(
			bundle_path.path_join(observer_artifact))
		_check(
			observer_frames["ok"] and observer_frames["records"].size() == 1,
			"%s is sealed and reopens as one schema-valid frame" % observer_artifact)
	_remove_tree(root)


func _test_destination_file_collision_is_rejected() -> void:
	print("- destination files are collisions, never overwrite targets")
	var root := _unique_root("destination_file_collision")
	var absolute_root := ProjectSettings.globalize_path(root)
	DirAccess.make_dir_recursive_absolute(absolute_root)
	var run_id := "trace_destination_file_collision"
	var final_path := absolute_root.path_join(run_id)
	var sentinel := FileAccess.open(final_path, FileAccess.WRITE)
	if sentinel != null:
		sentinel.store_string("trace-store-sentinel")
		sentinel.flush()
		sentinel = null
	var store = TraceStoreScript.new()
	var started: Dictionary = store.start(root, run_id, _manifest(run_id))
	_check(
		not bool(started["ok"])
			and String(started["code"]) == "RUN_RESERVATION_COLLISION",
		"a final-path regular file blocks TraceStore reservation")
	_check(
		FileAccess.get_file_as_string(final_path) == "trace-store-sentinel",
		"TraceStore collision detection preserves the existing file bytes")
	_check(
		not DirAccess.dir_exists_absolute(
			absolute_root.path_join("%s.partial" % run_id)),
		"TraceStore creates no partial candidate after a file collision")
	_remove_tree(root)


static func _manifest(run_id: String) -> Dictionary:
	return {
		"schema": "sporespore.lab.manifest.v1",
		"run_id": run_id,
		"status": "RUNNING",
		"experiment_id": "L0_TRACE_ROUND_TRIP",
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
			"observer_minimal_frames.jsonl",
			"observer_full_frames.jsonl",
			"observer_contact_frames.jsonl",
			"runtime_notes.jsonl",
			"summary.json",
		],
	}


static func _summary(run_id: String, frame_count: int, note_count: int) -> Dictionary:
	return {
		"schema": "sporespore.lab.summary.v1",
		"run_id": run_id,
		"termination": "completed",
		"evidence_validity": "valid",
		"hypothesis_result": "supported",
		"promotion": "pass",
		"frame_count": frame_count,
		"runtime_note_count": note_count,
		"first_frame_id": 0,
		"last_frame_id": frame_count - 1,
		"metrics": [],
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


static func _unique_root(label: String) -> String:
	return "res://.tmp/lab_bundle_tests/%s_%d_%d" % [
		label,
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
