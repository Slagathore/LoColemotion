extends SceneTree

const AttestationTestHelperScript := preload(
	"res://tests/helpers/lab_attestation_test_helper.gd")
const BundleValidatorScript := preload(
	"res://scripts/lab/run_bundle_validator.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const KnowledgeBaseScript := preload("res://scripts/lab/knowledge_base.gd")
const TraceStoreScript := preload("res://scripts/lab/trace_store.gd")
const TraceReplayScript := preload("res://scripts/lab/trace_replay.gd")

const HASH := "sha256:0000000000000000000000000000000000000000000000000000000000000000"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab trace playback tests ===")
	_test_recorded_evidence_replays_without_live_simulation()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_recorded_evidence_replays_without_live_simulation() -> void:
	print("- L0.4 reconstructs transforms, event order, mechanics, and metrics from files only")
	var root := _unique_root()
	var trust := AttestationTestHelperScript.create_trust_root(
		"trace_playback")
	_check(bool(trust.get("ok", false)),
		"isolated external test trust root initializes")
	if not bool(trust.get("ok", false)):
		_remove_tree(root)
		return
	var trust_root := String(trust["trust_root"])
	var validation_options := \
		AttestationTestHelperScript.validation_options(trust_root)
	var run_id := "trace_playback"
	var manifest := _manifest(run_id)
	var store = TraceStoreScript.new()
	var started: Dictionary = store.start(root, run_id, manifest)
	_check(started["ok"], "playback fixture reserves")
	if not started["ok"]:
		_remove_tree(root)
		AttestationTestHelperScript.remove_tree(trust_root)
		return
	for frame_id in 3:
		_check(
			store.append_frame(_core_frame(frame_id, float(frame_id) / 60.0))["ok"],
			"frame %d records" % frame_id)
	_check(store.append_runtime_note({
		"note_sequence": 0,
		"frame_id": 2,
		"source": "test_lab_trace_playback_no_physics",
		"severity": "info",
		"code": "PLAYBACK_READY",
		"message": "Playback evidence is sealed.",
		"evidence": {"terminal_frame": 2},
	})["ok"], "runtime note records")
	_check(store.append_event({
		"schema": "sporespore.lab.event.v1",
		"run_id": run_id,
		"event_sequence": 0,
		"frame_id": 1,
		"event": "MODE_TRANSITION",
		"subject_id": "body_0",
		"detector_local_ordinal": 0,
		"from": "STANCE",
		"to": "BRACE",
		"reason": "PLAYBACK_FIXTURE",
		"evidence": {},
	})["ok"], "ordered event records")
	for source_frame_id in 2:
		_check(store.append_mechanics({
			"schema": "sporespore.lab.mechanics.v1",
			"run_id": run_id,
			"transition": [source_frame_id, source_frame_id + 1],
			"dt_s": 1.0 / 60.0,
			"body_id": "body_0",
			"mass_kg": 1.0,
			"linear_momentum_before_n_s": [1.0, 0.0, 0.0],
			"linear_momentum_after_n_s": [1.0, 0.0, 0.0],
			"translational_kinetic_energy_before_j": 0.5,
			"translational_kinetic_energy_after_j": 0.5,
			"observed_acceleration_m_s2": [0.0, 0.0, 0.0],
			"expected_acceleration_m_s2": [0.0, 0.0, 0.0],
			"acceleration_residual_m_s2": [0.0, 0.0, 0.0],
			"expected_position_m": [
				float(source_frame_id + 1) / 60.0,
				1.0,
				0.0,
			],
			"position_residual_m": [0.0, 0.0, 0.0],
			"expected_velocity_m_s": [1.0, 0.0, 0.0],
			"velocity_residual_m_s": [0.0, 0.0, 0.0],
			"availability": {
				"/rotational_kinetic_energy_j": {
					"status": "unavailable",
					"reason": "PLAYBACK_FIXTURE_BODY_ONLY",
				},
			},
		})["ok"], "mechanics transition %d records" % source_frame_id)
	var finalized: Dictionary = store.finalize(manifest, _summary(run_id))
	if not finalized["ok"]:
		printerr(finalized)
	_check(finalized["ok"], "playback fixture finalizes")
	if not finalized["ok"]:
		_remove_tree(root)
		AttestationTestHelperScript.remove_tree(trust_root)
		return
	var bundle_path := String(finalized["bundle_path"])
	var attestation := AttestationTestHelperScript.attest_bundle(
		bundle_path, trust_root)
	if not bool(attestation.get("ok", false)):
		printerr(attestation)
	_check(bool(attestation.get("ok", false)),
		"playback fixture receives detached test attestation")
	if not bool(attestation.get("ok", false)):
		_remove_tree(root)
		AttestationTestHelperScript.remove_tree(trust_root)
		return

	var source := FileAccess.get_file_as_string("res://scripts/lab/trace_replay.gd")
	var forbidden := [
		"PhysicsServer3D",
		"PhysicsDirectSpaceState3D",
		"RigidBody3D",
		"physics_frame",
		"_physics_process",
	]
	var source_is_read_only := true
	for token in forbidden:
		source_is_read_only = source_is_read_only and not source.contains(token)
	_check(source_is_read_only, "replayer has no live-simulation API dependency")

	var old_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = 30
	var replay_30 := TraceReplayScript.replay_bundle(
		bundle_path, validation_options)
	Engine.physics_ticks_per_second = 120
	var replay_120 := TraceReplayScript.replay_bundle(
		bundle_path, validation_options)
	Engine.physics_ticks_per_second = old_ticks
	if not replay_30["ok"]:
		printerr(replay_30)
	if not replay_120["ok"]:
		printerr(replay_120)
	_check(replay_30["ok"] and replay_120["ok"], "completed bundle replays")
	_check(
		int(replay_30.get("simulation_steps", -1)) == 0
			and int(replay_120.get("simulation_steps", -1)) == 0,
		"playback advances zero simulation steps")
	_check(
		replay_30.get("timeline") == replay_120.get("timeline"),
		"live tick-rate changes cannot alter recorded timeline")
	if replay_30["ok"]:
		var timeline: Array = replay_30["timeline"]
		_check(timeline.size() == 3, "all three recorded transforms replay")
		_check(
			is_equal_approx(
				float(timeline[2]["body_transforms"]["body_0"]["origin"][0]),
				2.0 / 60.0),
			"terminal body transform matches recorded value")
		_check(
			replay_30["event_order"].size() == 1
				and String(replay_30["event_order"][0]["event"]) == "MODE_TRANSITION"
				and int(replay_30["event_order"][0]["frame_id"]) == 1,
			"event identity and ordering replay")
		_check(
			is_equal_approx(float(replay_30["metrics"]["terminal_x_m"]), 2.0 / 60.0),
			"derived summary metric replays")
		_check(
			replay_30["mechanics_records"].size() == 2
				and replay_30["mechanics_records"][1]["transition"] == [1.0, 2.0],
			"mechanics evidence replays without recalculation")
	_test_coherent_full_bundle_rewrite_is_rejected(
		bundle_path, run_id, validation_options)
	_remove_tree(root)
	AttestationTestHelperScript.remove_tree(trust_root)


func _test_coherent_full_bundle_rewrite_is_rejected(
		bundle_path: String,
		run_id: String,
		validation_options: Dictionary) -> void:
	print("- detached receipt rejects a coherent same-run full-bundle rewrite")
	var notes_path := bundle_path.path_join("runtime_notes.jsonl")
	var checksums_path := bundle_path.path_join("checksums.json")
	var original_notes := FileAccess.get_file_as_bytes(notes_path)
	var original_checksums := FileAccess.get_file_as_bytes(checksums_path)
	_check(
		not original_notes.is_empty() and not original_checksums.is_empty(),
		"original attested bytes are captured for exact restoration")
	if original_notes.is_empty() or original_checksums.is_empty():
		return

	var note_records := TraceStoreScript.read_jsonl(notes_path)
	if not bool(note_records.get("ok", false)) \
			or note_records.get("records", []).size() != 1:
		_check(false, "rewrite fixture runtime note is readable")
		return
	var rewritten_note: Dictionary = note_records["records"][0]
	rewritten_note["message"] = \
		"Internally coherent replacement bytes with the same run identity."
	_write_text(
		notes_path,
		CanonicalJsonScript.stringify(rewritten_note) + "\n")
	var rewritten_checksums := TraceStoreScript.build_checksums_for_parent(
		bundle_path, run_id)
	var checksum_write := TraceStoreScript.write_json_for_parent(
		checksums_path, rewritten_checksums)
	_check(bool(checksum_write.get("ok", false)),
		"rewritten bundle is resealed with matching unkeyed checksums")
	if not bool(checksum_write.get("ok", false)):
		_write_bytes(notes_path, original_notes)
		_write_bytes(checksums_path, original_checksums)
		return

	var structural_trust := AttestationTestHelperScript.create_trust_root(
		"trace_structural_only")
	_check(bool(structural_trust.get("ok", false)),
		"independent receipt-free structural trust root initializes")
	if not bool(structural_trust.get("ok", false)):
		_write_bytes(notes_path, original_notes)
		_write_bytes(checksums_path, original_checksums)
		return
	var structural_trust_root := String(structural_trust["trust_root"])
	var structural := BundleValidatorScript.validate_bundle(
		bundle_path,
		{"attestation_test_root": structural_trust_root})
	AttestationTestHelperScript.remove_tree(structural_trust_root)
	var required := BundleValidatorScript.validate_bundle(
		bundle_path,
		{
			"attestation_requirement": "required",
			"attestation_test_root":
				validation_options["attestation_test_root"],
		})
	var replay := TraceReplayScript.replay_bundle(
		bundle_path, validation_options)
	var knowledge := KnowledgeBaseScript.inspect_bundle(
		bundle_path, validation_options)
	_check(
		structural["ok"] and structural["can_finalize"],
		"ordinary structural validation accepts the coherent rewrite")
	_check(
		not required["ok"]
			and _validation_has_code(
				required, "PUBLICATION_ENVELOPE_MISMATCH"),
		"required validation rejects the rewrite against the old receipt")
	_check(
		not bool(replay.get("ok", false)),
		"replay fails closed on the unattested replacement bytes")
	_check(
		not bool(knowledge.get("ok", false)),
		"knowledge inspection fails closed on the unattested replacement bytes")

	_write_bytes(notes_path, original_notes)
	_write_bytes(checksums_path, original_checksums)
	var restored_validation := BundleValidatorScript.validate_bundle(
		bundle_path,
		{
			"attestation_requirement": "required",
			"attestation_test_root":
				validation_options["attestation_test_root"],
		})
	var restored_replay := TraceReplayScript.replay_bundle(
		bundle_path, validation_options)
	var restored_knowledge := KnowledgeBaseScript.inspect_bundle(
		bundle_path, validation_options)
	_check(
		restored_validation["ok"] and restored_validation["can_finalize"],
		"restoring the original exact bundle bytes restores attestation")
	_check(
		bool(restored_replay.get("ok", false)),
		"replay resumes only after exact-byte restoration")
	_check(
		bool(restored_knowledge.get("ok", false)),
		"knowledge inspection resumes only after exact-byte restoration")


static func _validation_has_code(
		validation: Dictionary,
		expected_code: String) -> bool:
	for issue_value in validation.get("errors", []):
		if (
			issue_value is Dictionary
			and String(issue_value.get("code", "")) == expected_code
		):
			return true
	return false


static func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.flush()
	file.close()


static func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(bytes)
	file.flush()
	file.close()


static func _manifest(run_id: String) -> Dictionary:
	return {
		"schema": "sporespore.lab.manifest.v1",
		"run_id": run_id,
		"status": "RUNNING",
		"experiment_id": "L0_4_TRACE_PLAYBACK",
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
			"events.jsonl",
			"mechanics.jsonl",
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
		"frame_count": 3,
		"runtime_note_count": 1,
		"first_frame_id": 0,
		"last_frame_id": 2,
		"metrics": [{
			"metric_id": "terminal_x_m",
			"value": 2.0 / 60.0,
			"unit": "m",
			"availability": "derived",
			"source_stream": "frames.jsonl",
			"source_frame_range": [0, 2],
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
	return "res://.tmp/lab_bundle_tests/replay_%d_%d" % [
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
