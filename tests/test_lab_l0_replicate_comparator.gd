extends SceneTree

const AttestationTestHelperScript := preload(
	"res://tests/helpers/lab_attestation_test_helper.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const ComparatorScript := preload(
	"res://scripts/lab/l0_replicate_comparator.gd")
const PublicationAttestationScript := preload(
	"res://scripts/lab/publication_attestation.gd")
const TraceStoreScript := preload("res://scripts/lab/trace_store.gd")

const HASH_ZERO := "sha256:0000000000000000000000000000000000000000000000000000000000000000"
const HASH_ONE := "sha256:1111111111111111111111111111111111111111111111111111111111111111"
const HASH_TWO := "sha256:2222222222222222222222222222222222222222222222222222222222222222"
const HASH_THREE := "sha256:3333333333333333333333333333333333333333333333333333333333333333"
const HASH_FOUR := "sha256:4444444444444444444444444444444444444444444444444444444444444444"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== BR1 L0 same-seed fresh-process replicate comparator ===")
	var root := _unique_root()
	var synthetic_trust := AttestationTestHelperScript.create_trust_root(
		"replicate_comparator_synthetic")
	_check(
		bool(synthetic_trust.get("ok", false)),
		"synthetic comparator creates isolated external test trust")
	if not bool(synthetic_trust.get("ok", false)):
		_remove_tree(root)
		_finish()
		return
	var synthetic_trust_root := String(synthetic_trust["trust_root"])
	var synthetic_validation_options := \
		AttestationTestHelperScript.validation_options(
			synthetic_trust_root)
	var left_result := _build_bundle(
		root, "replicate_left", 1001, "2026-07-19T01:00:00Z")
	var right_result := _build_bundle(
		root, "replicate_right", 1002, "2026-07-19T01:00:01Z")
	_check(left_result["ok"], "left synthetic replicate seals")
	_check(right_result["ok"], "right synthetic replicate seals")
	if not left_result["ok"] or not right_result["ok"]:
		printerr("left=", left_result)
		printerr("right=", right_result)
		_remove_tree(root)
		AttestationTestHelperScript.remove_tree(synthetic_trust_root)
		_finish()
		return

	var left_path := String(left_result["bundle_path"])
	var right_path := String(right_result["bundle_path"])
	var left_attestation := \
		PublicationAttestationScript.attest_with_test_trust_root(
			left_path,
			synthetic_trust_root,
			"2026-07-19T01:01:00Z")
	var right_attestation := \
		PublicationAttestationScript.attest_with_test_trust_root(
			right_path,
			synthetic_trust_root,
			"2026-07-19T01:01:01Z")
	_check(
		bool(left_attestation.get("ok", false))
			and bool(right_attestation.get("ok", false)),
		"both synthetic replicates receive detached test receipts")
	if not bool(left_attestation.get("ok", false)) \
			or not bool(right_attestation.get("ok", false)):
		printerr("left_attestation=", left_attestation)
		printerr("right_attestation=", right_attestation)
		_remove_tree(root)
		AttestationTestHelperScript.remove_tree(synthetic_trust_root)
		_finish()
		return
	var matching := ComparatorScript.compare(
		left_path, right_path, synthetic_validation_options)
	if not matching["ok"]:
		printerr("unexpected comparator mismatches=", matching["mismatches"])
	_check(
		matching["ok"],
		"distinct run IDs, clocks, paths, and child PIDs normalize to matching evidence")
	_check(
		bool(matching["left_validation"]["ok"])
			and bool(matching["right_validation"]["ok"]),
		"both bundles independently cross the validator boundary")
	_check(
		bool(matching["fresh_process_proof"]["ok"])
			and int(matching["fresh_process_proof"]["left"]["child_process_id"])
				!= int(matching["fresh_process_proof"]["right"]["child_process_id"])
			and int(matching["fresh_process_proof"]["left"]["parent_process_id"])
				!= int(matching["fresh_process_proof"]["right"]["parent_process_id"]),
		"sealed metadata proves two distinct successful outer and child processes")
	_check(
		matching["identity"]["left_digest"]
			== matching["identity"]["right_digest"],
		"same experiment, resource, seed, tick, observer, and configuration identity matches")
	_check(
		matching["left_evidence_digest"]
			== matching["right_evidence_digest"],
		"all sealed JSONL streams and summary science share one canonical digest")
	_check(
		bool(matching["post_read_validations"]["left"]["ok"])
			and bool(matching["post_read_validations"]["right"]["ok"])
			and matching["bundle_witnesses"]["left_initial"]
				== matching["bundle_witnesses"]["left_post_read"]
			and matching["bundle_witnesses"]["right_initial"]
				== matching["bundle_witnesses"]["right_post_read"],
		"post-read revalidation proves neither bundle changed during comparison")

	var divergent_result := _build_bundle(
		root,
		"replicate_divergent",
		1003,
		"2026-07-19T01:00:02Z")
	_check(
		bool(divergent_result.get("ok", false)),
		"independent divergent synthetic replicate seals")
	var divergent_path := String(divergent_result.get("bundle_path", ""))
	var perturbation := _perturb_and_reseal(
		divergent_path, "replicate_divergent")
	_check(
		perturbation["ok"],
		"one physics-bearing frame value is changed and the bundle is honestly resealed")
	if perturbation["ok"]:
		var divergent_attestation := \
			PublicationAttestationScript.attest_with_test_trust_root(
				divergent_path,
				synthetic_trust_root,
				"2026-07-19T01:01:02Z")
		_check(
			bool(divergent_attestation.get("ok", false)),
			"divergent replicate receives its own detached receipt")
		var divergent := ComparatorScript.compare(
			left_path,
			divergent_path,
			synthetic_validation_options)
		_check(
			bool(divergent["left_validation"]["ok"])
				and bool(divergent["right_validation"]["ok"]),
			"resealing preserves independent structural validity")
		_check(
			not divergent["ok"] and int(divergent["mismatch_count"]) > 0,
			"the replicate comparator rejects structurally valid scientific divergence")
		var exact_path_found := _has_mismatch(
				divergent["mismatches"],
				"VALUE_TYPE_MISMATCH",
				"/streams/frames.jsonl/frames/1/bodies/body_0/angular_velocity/2")
		if not exact_path_found:
			printerr("unexpected mismatch paths=", divergent["mismatches"])
		_check(
			exact_path_found,
			"the mismatch report identifies the exact changed frame/value path")
		var frame_report: Dictionary = (
			divergent["evidence"]["streams"]["comparisons"]["frames.jsonl"])
		_check(
			frame_report["left_digest"] != frame_report["right_digest"]
				and divergent["left_evidence_digest"]
					!= divergent["right_evidence_digest"],
			"machine-readable stream and whole-evidence digests expose the divergence")

	_remove_tree(root)
	AttestationTestHelperScript.remove_tree(synthetic_trust_root)
	_test_real_fresh_process_replicates()
	_finish()


func _test_real_fresh_process_replicates() -> void:
	print("- two real launch_lab outer/child executions compare as replicates")
	var root := OS.get_temp_dir().path_join(
		"sporespore_real_replicate_%d_%d" % [
			OS.get_process_id(),
			Time.get_ticks_usec(),
		]).replace("\\", "/")
	DirAccess.make_dir_recursive_absolute(root)
	var trust := AttestationTestHelperScript.create_trust_root(
		"replicate_comparator_real")
	_check(
		bool(trust.get("ok", false)),
		"real-launch comparator probe creates isolated external test trust")
	if not bool(trust.get("ok", false)):
		_remove_tree(root)
		return
	var trust_root := String(trust["trust_root"])
	var validation_options := \
		AttestationTestHelperScript.validation_options(trust_root)
	var first := _launch_outer(root, trust_root, 1)
	var second := _launch_outer(root, trust_root, 2)
	_check(
		int(first["exit_code"]) == 2 and int(second["exit_code"]) == 2,
		"two real outer launchers complete with the expected nonpromotion exit")
	_check(
		bool(first["engine_log_exists"])
			and bool(second["engine_log_exists"])
			and not _has_engine_error(
				String(first["output"]) + "\n"
				+ String(first["engine_log_text"]))
			and not _has_engine_error(
				String(second["output"]) + "\n"
				+ String(second["engine_log_text"])),
		"nested real outer logs contain no engine/script errors")
	var bundles := _completed_bundles(root)
	if bundles.size() != 2:
		printerr("first outer output=", first["output"])
		printerr("second outer output=", second["output"])
		printerr("completed bundles=", bundles)
	_check(
		bundles.size() == 2,
		"two outer launchers publish two completed fresh-child bundles")
	if bundles.size() == 2:
		for bundle_path in bundles:
			var child_engine_log := bundle_path.path_join("engine.log")
			_check(
				FileAccess.file_exists(child_engine_log)
					and not _has_engine_error(
						FileAccess.get_file_as_string(child_engine_log)),
				"sealed real child engine log contains no engine/script errors")
		var compared := ComparatorScript.compare(
			bundles[0], bundles[1], validation_options)
		if not compared["ok"]:
			printerr("real replicate mismatches=", compared["mismatches"])
		_check(
			compared["ok"],
			"real launch plans, PIDs, argv paths, and clocks do not leak into scientific equality")
		var real_process_proof: Dictionary = compared.get(
			"fresh_process_proof", {})
		_check(
			bool(real_process_proof.get("ok", false))
				and compared["left_evidence_digest"]
					== compared["right_evidence_digest"],
			"real fresh children produce one exact same-seed scientific witness")
		var left_stats: Dictionary = compared.get(
			"left_validation", {}).get("stats", {})
		var right_stats: Dictionary = compared.get(
			"right_validation", {}).get("stats", {})
		var left_publication: Dictionary = left_stats.get(
			"publication_attestation", {})
		var right_publication: Dictionary = right_stats.get(
			"publication_attestation", {})
		_check(
			bool(left_publication.get("ok", false))
				and bool(right_publication.get("ok", false))
				and left_publication.get("trust_mode") == "test"
				and right_publication.get("trust_mode") == "test",
			"both real replicate bundles require valid isolated test receipts")
	_remove_tree(root)
	AttestationTestHelperScript.remove_tree(trust_root)


func _launch_outer(
		root: String,
		trust_root: String,
		ordinal: int) -> Dictionary:
	var output: Array = []
	var engine_log_path := root.path_join("outer_%d.log" % ordinal)
	var arguments := [
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--log-file",
		engine_log_path,
		"--script",
		"res://scripts/lab/launch_lab.gd",
		"--",
		"--experiment-spec",
		"res://data/lab/experiments/br1/BR1_L0_0_stationary_60hz_v1.tres",
		"--seed",
		"42",
		"--observer",
		"full_contacts_v1",
		"--output-root",
		root,
		"--attestation-test-root",
		trust_root,
	]
	var exit_code := OS.execute(
		OS.get_executable_path(), arguments, output, true)
	var engine_log_exists := FileAccess.file_exists(engine_log_path)
	return {
		"exit_code": exit_code,
		"output": "\n".join(output),
		"engine_log_path": engine_log_path,
		"engine_log_exists": engine_log_exists,
		"engine_log_text": (
			FileAccess.get_file_as_string(engine_log_path)
			if engine_log_exists
			else ""
		),
	}


static func _has_engine_error(text: String) -> bool:
	var pattern := RegEx.create_from_string(
		"(?im)^\\s*(?:SCRIPT ERROR:|ERROR:).*$")
	return pattern.search(text) != null


static func _completed_bundles(root: String) -> Array[String]:
	var result: Array[String] = []
	var access := DirAccess.open(root)
	if access == null:
		return result
	for directory_name in access.get_directories():
		if not directory_name.ends_with(".partial"):
			result.append(root.path_join(directory_name))
	result.sort()
	return result


func _build_bundle(
		root: String,
		run_id: String,
		child_process_id: int,
		started_utc: String) -> Dictionary:
	var manifest := _manifest(run_id, started_utc)
	var store = TraceStoreScript.new()
	var started: Dictionary = store.start(root, run_id, manifest)
	if not started["ok"]:
		return started
	var metadata_write := TraceStoreScript.write_json_for_parent(
		String(started["partial_path"]).path_join("process_metadata.json"),
		_process_metadata(run_id, child_process_id, started_utc))
	if not metadata_write["ok"]:
		return metadata_write
	for frame_id in 2:
		var frame_result: Dictionary = store.append_frame(
			_frame(frame_id, float(frame_id) / 60.0))
		if not frame_result["ok"]:
			return frame_result
	var note_result: Dictionary = store.append_runtime_note({
		"note_sequence": 0,
		"frame_id": null,
		"source": "test_lab_l0_replicate_comparator",
		"severity": "info",
		"code": "SYNTHETIC_REPLICATE_READY",
		"message": "Same-seed synthetic evidence is complete.",
		"evidence": {
			"root_seed": 42,
			"physics_ticks_per_second": 60,
		},
	})
	if not note_result["ok"]:
		return note_result
	return store.finalize(manifest, _summary(run_id))


static func _manifest(run_id: String, started_utc: String) -> Dictionary:
	var body_dynamics := {
		"mass_kg": 1.0,
		"gravity_scale": 0.0,
		"initial_position_m": [0.0, 1.0, 0.0],
		"initial_velocity_m_s": [1.0, 0.0, 0.0],
		"linear_damp_s1": 0.0,
		"angular_damp_s1": 0.0,
	}
	return {
		"schema": "sporespore.lab.manifest.v1",
		"run_id": run_id,
		"status": "RUNNING",
		"experiment_id": "BR1_REPLICATE_COMPARATOR_PROBE",
		"hypothesis_id": "same_seed_fresh_process_is_exact",
		"experiment_resource_path":
			"res://data/lab/experiments/br1/replicate_probe_v1.tres",
		"experiment_resource_sha256": HASH_ONE,
		"fixture_id": "replicate_probe_fixture",
		"fixture_version": 1,
		"fixture_resource_path":
			"res://scripts/lab/rigs/stationary_body_rig.gd",
		"fixture_resource_sha256": HASH_TWO,
		"loaded_resource_hashes": {
			"res://data/lab/experiments/br1/replicate_probe_v1.tres":
				HASH_ONE,
			"res://scripts/lab/rigs/stationary_body_rig.gd": HASH_TWO,
		},
		"schema_set": "sporespore.lab.schemas.v1",
		"recorder_version": "flight-recorder-v1",
		"expanded_spec_sha256": HASH_THREE,
		"resolved_configuration_sha256": HASH_FOUR,
		"applied_configuration_sha256": HASH_FOUR,
		"git_commit": "synthetic-test-commit",
		"dirty_worktree": true,
		"dirty_diff_sha256": HASH_ZERO,
		"execution_mode": "development",
		"reproducibility": "partial_dirty_source",
		"godot_version": "4.7.stable.mono.official",
		"godot_commit": "synthetic",
		"physics_backend": "Jolt Physics",
		"physics_backend_adapter": "rigid_body_integrate_forces_v1",
		"platform": "Windows-x86_64",
		"physics_ticks_per_second": 60,
		"solver_velocity_iterations": 20,
		"solver_position_iterations": 4,
		"observer_profile": "full_contacts_v1",
		"observer_channel_set_sha256": HASH_ZERO,
		"observer_parity_envelope_id": null,
		"contact_cap_per_body": 16,
		"process_isolation": "outer_parent_reserved_fresh_godot_v1",
		"body_dynamics": body_dynamics,
		"joint_dynamics": {},
		"surface_materials": {},
		"seed_root": 42,
		"rng_derivation": "sporespore-lab-seed-v1-sha256-low52",
		"rng_streams": {
			"controller": {
				"seed": 4242,
				"seed_sha256": HASH_ONE,
			},
		},
		"scaffolds_allowed": [],
		"scaffolds_forbidden": ["hidden_support"],
		"expanded_parameters": {
			"experiment_id": "BR1_REPLICATE_COMPARATOR_PROBE",
			"root_seed": 42,
			"physics_ticks_per_second": 60,
			"observer_profile_id": "full_contacts_v1",
			"body_parameters": body_dynamics,
		},
		"comparison_role": null,
		"paired_run_id": null,
		"units": "SI",
		"started_utc": started_utc,
		"required_artifacts": [
			"manifest.json",
			"process_metadata.json",
			"frames.jsonl",
			"runtime_notes.jsonl",
			"summary.json",
		],
	}


static func _process_metadata(
		run_id: String,
		child_process_id: int,
		started_utc: String) -> Dictionary:
	var parent_process_id := child_process_id + 10000
	var unavailable := {
		"status": "unavailable",
		"path": null,
		"mechanism": "synthetic_fixture",
		"reason": "No external log exists for this synthetic bundle.",
	}
	return {
		"schema": "sporespore.lab.process_metadata.v1",
		"run_id": run_id,
		"status": "COMPLETE",
		"parent_process_id": parent_process_id,
		"child_process_id": child_process_id,
		"executable": "C:/synthetic/%s/godot.exe" % run_id,
		"arguments": ["--synthetic-run", run_id],
		"engine_arguments": ["--headless"],
		"user_arguments": ["--synthetic-run", run_id],
		"requested_user_arguments": ["--synthetic-run", run_id],
		"argument_capture_quality": "launcher_exact",
		"working_directory": "C:/synthetic/%s" % run_id,
		"started_utc": started_utc,
		"ended_utc": started_utc,
		"exit_disposition": "promotion_pass",
		"exit_code": 0,
		"log_paths": {
			"engine_log": unavailable.duplicate(true),
			"stdout": unavailable.duplicate(true),
			"stderr": unavailable.duplicate(true),
		},
		"reservation_id": run_id.sha256_text().substr(0, 32),
		"launch_plan_path": null,
		"launch_plan_sha256": null,
		"launch_plan_payload_sha256": CanonicalJsonScript.sha256({
			"run_id": run_id,
			"parent_process_id": parent_process_id,
			"child_process_id": child_process_id,
			"started_utc": started_utc,
		}),
		"adoption_token_sha256": null,
		"partial_path": "C:/synthetic/%s.partial" % run_id,
		"final_path": "C:/synthetic/%s" % run_id,
		"termination_observer_process_id": parent_process_id,
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
		"gate_results": {
			"physical": {
				"gate_id": "synthetic_exact_replicate_v1",
				"pass": true,
				"checks": [{
					"metric_id": "terminal_x",
					"observed": 1.0 / 60.0,
					"limit": 1.0,
					"operator": "<=",
					"pass": true,
					"reason": "inside synthetic limit",
				}],
				"reason": "synthetic gate passed",
			},
		},
	}


static func _frame(frame_id: int, time_s: float) -> Dictionary:
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
					"basis": [
						[1.0, 0.0, 0.0],
						[0.0, 1.0, 0.0],
						[0.0, 0.0, 1.0],
					],
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


static func _perturb_and_reseal(
		bundle_path: String,
		run_id: String) -> Dictionary:
	var frames_path := bundle_path.path_join("frames.jsonl")
	var read := TraceStoreScript.read_jsonl(frames_path)
	if not read["ok"] or read["records"].size() != 2:
		return {"ok": false, "stage": "read_frames", "detail": read}
	var records: Array = read["records"]
	records[1]["bodies"]["body_0"]["angular_velocity"][2] = 0.125
	var file := FileAccess.open(frames_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "stage": "write_frames"}
	for record in records:
		file.store_line(CanonicalJsonScript.stringify(record))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return {
			"ok": false,
			"stage": "flush_frames",
			"error": error_string(write_error),
		}
	var checksums := TraceStoreScript.build_checksums_for_parent(
		bundle_path, run_id)
	var checksum_write := TraceStoreScript.write_json_for_parent(
		bundle_path.path_join("checksums.json"), checksums)
	return {
		"ok": bool(checksum_write.get("ok", false)),
		"stage": "reseal",
		"detail": checksum_write,
	}


static func _has_mismatch(
		mismatches: Array,
		code: String,
		path: String) -> bool:
	for raw in mismatches:
		if String(raw.get("code", "")) == code \
				and String(raw.get("path", "")) == path:
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


static func _unique_root() -> String:
	return "res://.tmp/lab_replicate_comparator/comparator_%d_%d" % [
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
