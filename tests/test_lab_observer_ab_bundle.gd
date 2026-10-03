extends SceneTree

const ReportBuilderScript := preload("res://scripts/lab/report_builder.gd")
const TraceStoreScript := preload("res://scripts/lab/trace_store.gd")

const HASH := "sha256:0000000000000000000000000000000000000000000000000000000000000000"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab synthetic observer A/B comparison provenance ===")
	var root := OS.get_temp_dir().path_join(
		"sporespore_observer_bundle_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(root)
	var valid := _build_bundle(root, "observer_ab_valid", 0.2)
	if not bool(valid.get("ok", false)):
		printerr(valid)
	_check(bool(valid.get("ok", false)),
		"two-operand metric reproduces from three sealed observer streams")
	if bool(valid.get("ok", false)):
		var validation: Dictionary = valid["validation"]
		_check(
			bool(validation["ok"]) and bool(validation["can_finalize"]),
			"synthetic comparison bundle passes independent validation")

	var forged := _build_bundle(root, "observer_ab_forged", 0.125)
	_check(not bool(forged.get("ok", false)),
		"comparison value that does not match its operands cannot finalize")
	_check(
		_error_message_contains(forged, "does not reproduce"),
		"failed comparison names the sealed-operand reproduction mismatch")
	_remove_tree(root)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _build_bundle(
		root: String,
		run_id: String,
		recorded_delta: float) -> Dictionary:
	var manifest := _manifest(run_id)
	var store = TraceStoreScript.new()
	var started: Dictionary = store.start(root, run_id, manifest)
	if not started["ok"]:
		return started
	for frame_id in 2:
		var minimal_x := float(frame_id)
		var full_x := minimal_x + (0.1 if frame_id == 0 else 0.2)
		var contact_x := full_x + 0.05
		var minimal := _frame(frame_id, minimal_x, "minimal_state_v1")
		var full := _frame(frame_id, full_x, "full_state_v1")
		var contact := _frame(frame_id, contact_x, "full_contacts_v1")
		if not store.append_frame(contact)["ok"]:
			return {"ok": false, "message": "primary frame append failed"}
		for pair in [
			["observer_minimal_frames", minimal],
			["observer_full_frames", full],
			["observer_contact_frames", contact],
		]:
			var appended: Dictionary = store.append_observer_frame(
				String(pair[0]), pair[1])
			if not appended["ok"]:
				return appended
	var note_append: Dictionary = store.append_runtime_note({
		"note_sequence": 0,
		"frame_id": 1,
		"source": "test_lab_observer_ab_bundle",
		"severity": "info",
		"code": "OBSERVER_COMPARISON_READY",
		"message": "All comparison operands are sealed.",
		"evidence": {},
	})
	if not note_append["ok"]:
		return note_append
	var metric := ReportBuilderScript.comparison_metric(
		run_id,
		"max_position_delta_m",
		recorded_delta,
		"m",
		"observer_minimal_frames.jsonl",
		"observer_full_frames.jsonl",
		[0, 1],
		"/bodies/body_0/transform/origin",
		"max_pairwise_vec3_distance_v1",
		1,
		0.0)
	return store.finalize(manifest, {
		"termination": "completed",
		"evidence_validity": "valid",
		"hypothesis_result": "supported",
		"promotion": "not_evaluated",
		"frame_count": 2,
		"runtime_note_count": 1,
		"first_frame_id": 0,
		"last_frame_id": 1,
		"metrics": [metric],
	})


static func _manifest(run_id: String) -> Dictionary:
	return {
		"schema": "sporespore.lab.manifest.v1",
		"run_id": run_id,
		"status": "RUNNING",
		# This fixture isolates pairwise metric recomputation. It is not the
		# production L0.3 experiment and therefore must not borrow L0.3's full
		# process/configuration/artifact contract.
		"experiment_id": "SYNTHETIC_OBSERVER_AB_PAIRWISE_VALIDATOR",
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


static func _frame(
		frame_id: int,
		x: float,
		profile_id: String) -> Dictionary:
	return {
		"schema_version": "frame_v1",
		"frame_id": frame_id,
		"physics_step_id": frame_id,
		"capture_epoch": frame_id,
		"physics_time_s": float(frame_id) / 60.0,
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
					"basis": [
						[1.0, 0.0, 0.0],
						[0.0, 1.0, 0.0],
						[0.0, 0.0, 1.0],
					],
					"origin": [x, 1.0, 0.0],
				},
				"center_of_mass_world": [x, 1.0, 0.0],
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
				"observer_profile_id": profile_id,
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


func _error_message_contains(result: Dictionary, needle: String) -> bool:
	for error_value in result.get("details", []):
		if String(error_value.get("message", "")).contains(needle):
			return true
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


static func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var access := DirAccess.open(path)
	for file_name in access.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	for directory_name in access.get_directories():
		_remove_tree(path.path_join(directory_name))
	DirAccess.remove_absolute(path)
