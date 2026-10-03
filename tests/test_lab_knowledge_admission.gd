extends SceneTree

const AttestationTestHelperScript := preload(
	"res://tests/helpers/lab_attestation_test_helper.gd")
const KnowledgeBaseScript := preload("res://scripts/lab/knowledge_base.gd")
const KnowledgeQueryScript := preload("res://scripts/lab/knowledge_query.gd")
const TraceStoreScript := preload("res://scripts/lab/trace_store.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const AdmissionCliScript := preload("res://scripts/lab/admit_knowledge.gd")

const HASH := "sha256:0000000000000000000000000000000000000000000000000000000000000000"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab knowledge-admission contract ===")
	var root := OS.get_temp_dir().path_join(
		"sporespore_knowledge_%d_%d" % [
			OS.get_process_id(),
			Time.get_ticks_usec(),
		])
	DirAccess.make_dir_recursive_absolute(root)
	var trust := AttestationTestHelperScript.create_trust_root(
		"knowledge_admission")
	_check(bool(trust.get("ok", false)),
		"isolated external test trust root initializes")
	if not bool(trust.get("ok", false)):
		_remove_tree(root)
		_finish()
		return
	var trust_root := String(trust["trust_root"])
	var validation_options := \
		AttestationTestHelperScript.validation_options(trust_root)
	var nested_output := AdmissionCliScript._parse_arguments(PackedStringArray([
		"--bundle", root,
		"--draft", "res://data/lab/knowledge/drafts/example.json",
		"--output", "res://data/lab/knowledge/entries/hidden/example.json",
	]))
	_check(
		not nested_output["ok"],
		"CLI forbids nested entry paths that the flat catalog cannot discover")
	var bundle := _development_bundle(root)
	_check(bool(bundle.get("ok", false)),
		"synthetic development evidence finalizes structurally")
	if not bool(bundle.get("ok", false)):
		_remove_tree(root)
		AttestationTestHelperScript.remove_tree(trust_root)
		_finish()
		return
	var attestation := AttestationTestHelperScript.attest_bundle(
		String(bundle["bundle_path"]), trust_root)
	if not bool(attestation.get("ok", false)):
		printerr(attestation)
	_check(bool(attestation.get("ok", false)),
		"synthetic development evidence receives detached test attestation")
	if not bool(attestation.get("ok", false)):
		_remove_tree(root)
		AttestationTestHelperScript.remove_tree(trust_root)
		_finish()
		return
	var draft := _draft()
	var proposal: Dictionary = KnowledgeBaseScript.propose_from_bundle(
		bundle["bundle_path"],
		draft,
		"development_observation",
		validation_options)
	_check(bool(proposal.get("ok", false)),
		"valid finalized bundle can propose a development observation")
	if bool(proposal.get("ok", false)):
		var entry: Dictionary = proposal["entry"]
		_check(entry["claim_status"] == "development_observation",
			"dirty-source evidence remains explicitly developmental")
		_check(not bool(entry["evidence"]["bundle_can_promote"]),
			"entry retains the validator's non-promotion truth")
		_check(String(entry["evidence"]["manifest_sha256"]).begins_with("sha256:"),
			"entry pins exact manifest bytes")
		_check(String(entry["evidence"]["summary_sha256"]).begins_with("sha256:"),
			"entry pins exact summary bytes")
		_check(
			entry["evidence"]["manifest_sha256"]
				== "sha256:%s" % FileAccess.get_sha256(
					String(bundle["bundle_path"]).path_join("manifest.json"))
				and entry["evidence"]["summary_sha256"]
					== "sha256:%s" % FileAccess.get_sha256(
						String(bundle["bundle_path"]).path_join("summary.json"))
				and entry["evidence"]["checksums_sha256"]
					== "sha256:%s" % FileAccess.get_sha256(
						String(bundle["bundle_path"]).path_join("checksums.json")),
			"entry hashes equal the exact sealed source bytes")
		_check(
			entry["admission"]["payload_sha256"]
				== _entry_payload_sha256(entry),
			"admission digest binds the complete authored entry payload")
		_check(entry.is_read_only(), "proposed knowledge value is immutable")

	var accepted: Dictionary = KnowledgeBaseScript.propose_from_bundle(
		bundle["bundle_path"], draft, "accepted", validation_options)
	_check(
		not bool(accepted.get("ok", false))
			and accepted.get("code") == "ACCEPTED_KNOWLEDGE_REQUIRES_PROMOTION",
		"development evidence cannot be mislabeled as accepted guidance")
	var refuted: Dictionary = KnowledgeBaseScript.propose_from_bundle(
		bundle["bundle_path"], draft, "refuted", validation_options)
	_check(
		not bool(refuted.get("ok", false)),
		"development evidence cannot suppress accepted guidance as refuted")

	if bool(proposal.get("ok", false)):
		var entry: Dictionary = proposal["entry"]
		var entry_path := root.path_join("entries/L0.test.entry.json")
		var first_write: Dictionary = KnowledgeBaseScript.write_new_entry(
			entry_path, entry, validation_options)
		var second_write: Dictionary = KnowledgeBaseScript.write_new_entry(
			entry_path, entry, validation_options)
		_check(bool(first_write.get("ok", false)),
			"validated entry writes atomically")
		_check(
			not bool(second_write.get("ok", false))
				and second_write.get("code") == "KNOWLEDGE_ENTRY_ALREADY_EXISTS",
			"knowledge history cannot be overwritten in place")
		_check(
			not DirAccess.dir_exists_absolute("%s.admission-lock" % entry_path),
			"admission reservation is released after terminal outcomes")

		var accepted_only: Dictionary = KnowledgeQueryScript.load_entries(
			root.path_join("entries"), false, validation_options)
		var development_visible: Dictionary = KnowledgeQueryScript.load_entries(
			root.path_join("entries"), true, validation_options)
		if not accepted_only["ok"] or not development_visible["ok"]:
			printerr("accepted_only_catalog=", accepted_only)
			printerr("development_catalog=", development_visible)
		_check(
			accepted_only["ok"]
				and development_visible["ok"]
				and accepted_only["entries"].is_empty()
				and development_visible["entries"].size() == 1,
			"trusted query excludes development evidence unless explicitly requested")
		var candidates: Array = KnowledgeQueryScript.repair_candidates(
			development_visible["entries"],
			["body_agnostic"],
			"drift",
			validation_options)
		_check(
			candidates.size() == 1
				and not bool(candidates[0]["automatic_application_allowed"]),
			"development repair idea is inspectable but cannot auto-edit a creature")
		var unrelated_candidates: Array = KnowledgeQueryScript.repair_candidates(
			development_visible["entries"],
			["unrelated_morphology"],
			"drift",
			validation_options)
		_check(
			unrelated_candidates.size() == 1,
			"body-agnostic evidence explicitly matches an unusual morphology")
		var specific_draft := _draft()
		specific_draft["entry_id"] = "L0.test.specific_morphology"
		specific_draft["morphology_tags"] = ["two_link_leg"]
		var specific_proposal: Dictionary = \
			KnowledgeBaseScript.propose_from_bundle(
				bundle["bundle_path"],
				specific_draft,
				"development_observation",
				validation_options)
		var no_morphology_match: Array = []
		if specific_proposal["ok"]:
			no_morphology_match = KnowledgeQueryScript.repair_candidates(
				[specific_proposal["entry"]],
				["distributed_gecko_foot"],
				"drift",
				validation_options)
		_check(
			specific_proposal["ok"] and no_morphology_match.is_empty(),
			"repair retrieval rejects unrelated morphology evidence")

		var forged_accepted: Dictionary = _mutable_copy(entry)
		forged_accepted["claim_status"] = "accepted"
		forged_accepted["evidence"]["bundle_can_promote"] = true
		forged_accepted["evidence"]["promotion"] = "pass"
		var forged_path := root.path_join("entries/L0.forged.accepted.json")
		var forged_write: Dictionary = KnowledgeBaseScript.write_new_entry(
			forged_path, forged_accepted, validation_options)
		_check(
			not bool(forged_write.get("ok", false))
				and not FileAccess.file_exists(forged_path),
			"schema-valid caller data cannot write a forged accepted entry")
		var forged_candidates: Array = KnowledgeQueryScript.repair_candidates(
			[forged_accepted],
			["body_agnostic"],
			"drift",
			validation_options)
		_check(
			forged_candidates.is_empty(),
			"candidate generation independently rejects forged accepted data")

		_write_json(forged_path, forged_accepted)
		var catalog_with_forgery: Dictionary = KnowledgeQueryScript.load_entries(
			root.path_join("entries"), true, validation_options)
		_check(
			not catalog_with_forgery["ok"]
				and catalog_with_forgery["entries"].is_empty(),
			"one untrusted catalog record fails the entire query closed")
		DirAccess.remove_absolute(forged_path)

		var tampered_entry: Dictionary = _mutable_copy(entry)
		tampered_entry["minimal_repair_rules"][0]["smallest_change"] = \
			"silently replace the authored creature"
		_write_json(entry_path, tampered_entry)
		var tampered_catalog: Dictionary = KnowledgeQueryScript.load_entries(
			root.path_join("entries"), true, validation_options)
		_check(
			not tampered_catalog["ok"]
				and tampered_catalog["entries"].is_empty(),
			"post-admission repair-text tampering fails its payload digest")
		_write_json(entry_path, entry)
		var restored_catalog: Dictionary = KnowledgeQueryScript.load_entries(
			root.path_join("entries"), true, validation_options)
		if not restored_catalog["ok"]:
			printerr("restored_catalog=", restored_catalog)
		_check(
			restored_catalog["ok"]
				and restored_catalog["entries"].size() == 1,
			"exact admitted bytes restore a trusted development query")

		var summary_path := String(bundle["bundle_path"]).path_join(
			"summary.json")
		var summary_file := FileAccess.open(summary_path, FileAccess.READ_WRITE)
		if summary_file != null:
			summary_file.seek_end()
			summary_file.store_string(" ")
			summary_file.flush()
			summary_file.close()
		var source_tamper_verification: Dictionary = \
			KnowledgeBaseScript.verify_entry(
				entry, false, validation_options)
		var source_tamper_catalog: Dictionary = KnowledgeQueryScript.load_entries(
			root.path_join("entries"), true, validation_options)
		var post_tamper_path := root.path_join(
			"entries/L0.after.source.tamper.json")
		var post_tamper_write: Dictionary = KnowledgeBaseScript.write_new_entry(
			post_tamper_path, entry, validation_options)
		_check(
			not bool(source_tamper_verification.get("ok", false)),
			"changed bundle bytes invalidate their admitted provenance")
		_check(
			not source_tamper_catalog["ok"]
				and source_tamper_catalog["entries"].is_empty(),
			"automatic query returns nothing after source-bundle tampering")
		_check(
			not bool(post_tamper_write.get("ok", false))
				and not FileAccess.file_exists(post_tamper_path),
			"writer revalidates the bundle immediately before every append")
	_remove_tree(root)
	AttestationTestHelperScript.remove_tree(trust_root)
	_finish()


func _development_bundle(root: String) -> Dictionary:
	var run_id := "knowledge_development"
	var manifest := {
		"schema": "sporespore.lab.manifest.v1",
		"run_id": run_id,
		"status": "RUNNING",
		"experiment_id": "L0_KNOWLEDGE_TEST",
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
	var store = TraceStoreScript.new()
	var started: Dictionary = store.start(root, run_id, manifest)
	if not started["ok"]:
		return started
	var frame_append: Dictionary = store.append_frame(_frame())
	if not frame_append["ok"]:
		return frame_append
	var note_append: Dictionary = store.append_runtime_note({
		"note_sequence": 0,
		"frame_id": 0,
		"source": "test_lab_knowledge_admission",
		"severity": "info",
		"code": "DEVELOPMENT_OBSERVATION",
		"message": "Synthetic knowledge admission fixture.",
		"evidence": {},
	})
	if not note_append["ok"]:
		return note_append
	return store.finalize(manifest, {
		"termination": "completed",
		"evidence_validity": "valid",
		"hypothesis_result": "supported",
		"promotion": "not_evaluated",
		"frame_count": 1,
		"runtime_note_count": 1,
		"first_frame_id": 0,
		"last_frame_id": 0,
		"metrics": [],
	})


static func _draft() -> Dictionary:
	return {
		"entry_id": "L0.test.no_invented_motion",
		"title": "No invented isolated-body motion",
		"claim": "A stationary zero-gravity isolated body retained its state.",
		"scope": "One synthetic BR1 admission fixture.",
		"mechanism": "No force, impulse, contact, or gravity was present.",
		"applicability": ["isolated rigid-body calibration"],
		"failure_boundaries": ["Not evidence of standing or locomotion."],
		"morphology_tags": ["body_agnostic"],
		"parameter_effects": [],
		"minimal_repair_rules": [{
			"symptom": "isolated body drifts without an applied force",
			"diagnosis": "measurement or engine baseline is not yet trustworthy",
			"smallest_change": "fix the L0 observer or fixture before controller tuning",
			"expected_effect": "zero unexplained displacement in L0.0",
			"identity_preserved": ["all creature geometry"],
			"do_not_apply_when": ["a sealed external force or contact exists"],
		}],
		"unknowns": ["Articulated-body behavior remains untested."],
	}


static func _mutable_copy(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


static func _entry_payload_sha256(entry: Dictionary) -> String:
	var payload: Dictionary = {}
	for key_value in entry:
		if String(key_value) != "admission":
			payload[key_value] = entry[key_value]
	return CanonicalJsonScript.sha256(payload)


static func _write_json(path: String, value: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(CanonicalJsonScript.stringify(value) + "\n")
	file.flush()
	file.close()


static func _frame() -> Dictionary:
	return {
		"schema_version": "frame_v1",
		"frame_id": 0,
		"physics_step_id": 0,
		"capture_epoch": 0,
		"physics_time_s": 0.0,
		"sample_phase": "integrate_callback",
		"experiment_phase": "MEASURE",
		"release_frame_id": 0,
		"bodies": {
			"body_0": {
				"physics_step_id": 0,
				"body_callback_sequence": 1,
				"capture_epoch": 0,
				"sample_phase": "integrate_callback",
				"body_id": "body_0",
				"part_index": 0,
				"transform": {
					"basis": [
						[1.0, 0.0, 0.0],
						[0.0, 1.0, 0.0],
						[0.0, 0.0, 1.0],
					],
					"origin": [0.0, 1.0, 0.0],
				},
				"center_of_mass_world": [0.0, 1.0, 0.0],
				"linear_velocity": [0.0, 0.0, 0.0],
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
	if not DirAccess.dir_exists_absolute(path):
		return
	var access := DirAccess.open(path)
	for file_name in access.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	for directory_name in access.get_directories():
		_remove_tree(path.path_join(directory_name))
	DirAccess.remove_absolute(path)
