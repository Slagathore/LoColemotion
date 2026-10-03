# This validator intentionally keeps the complete cross-artifact contract in
# one auditable module. Splitting semantic passes across independently callable
# files would make it easier to bypass part of the promotion boundary.
# gdlint: disable=max-file-lines
class_name LabRunBundleValidator
extends RefCounted

const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")
const FailureCodesScript := preload("res://scripts/lab/failure_codes.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const SourceStateGateScript := preload("res://scripts/lab/source_state_gate.gd")
const ObserverProfileScript := preload("res://scripts/lab/observer_profile.gd")
const GateEvaluatorScript := preload("res://scripts/lab/gate_evaluator.gd")
const SpecCompilerScript := preload("res://scripts/lab/spec_compiler.gd")
const L0MetricRecomputerScript := preload(
	"res://scripts/lab/l0_metric_recomputer.gd")
const PublicationAttestationScript := preload(
	"res://scripts/lab/publication_attestation.gd")
const AttestedBundleSnapshotScript := preload(
	"res://scripts/lab/attested_bundle_snapshot.gd")

const SCHEMA_BY_ARTIFACT := {
	"manifest.json": "res://data/lab/schemas/manifest_v1.schema.json",
	"frames.jsonl": "res://data/lab/schemas/frame_v1.schema.json",
	"observer_minimal_frames.jsonl": "res://data/lab/schemas/frame_v1.schema.json",
	"observer_full_frames.jsonl": "res://data/lab/schemas/frame_v1.schema.json",
	"observer_contact_frames.jsonl": "res://data/lab/schemas/frame_v1.schema.json",
	"commands.jsonl": "res://data/lab/schemas/command_v1.schema.json",
	"applications.jsonl": "res://data/lab/schemas/application_v1.schema.json",
	"decisions.jsonl": "res://data/lab/schemas/decision_v1.schema.json",
	"interventions.jsonl": "res://data/lab/schemas/intervention_v1.schema.json",
	"mechanics.jsonl": "res://data/lab/schemas/mechanics_v1.schema.json",
	"events.jsonl": "res://data/lab/schemas/event_v1.schema.json",
	"runtime_notes.jsonl": "res://data/lab/schemas/runtime_note_v1.schema.json",
	"pre_event_snapshot.jsonl": "res://data/lab/schemas/pre_event_entry_v1.schema.json",
	"configuration.json": "res://data/lab/schemas/configuration_v1.schema.json",
	"launch_plan.json": "res://data/lab/schemas/launch_plan_v1.schema.json",
	"process_metadata.json": "res://data/lab/schemas/process_metadata_v1.schema.json",
	"summary.json": "res://data/lab/schemas/summary_v1.schema.json",
	"checksums.json": "res://data/lab/schemas/checksums_v1.schema.json",
}
const CORE_ARTIFACTS: Array[String] = [
	"manifest.json",
	"frames.jsonl",
	"runtime_notes.jsonl",
	"summary.json",
]
const CURRENT_L0_EXPERIMENTS: Array[String] = [
	"L0_0_STATIONARY_GRAVITY_OFF",
	"L0_1_FREE_FALL",
	"L0_2_BALLISTIC_ZERO_G",
	"L0_3_OBSERVER_AB",
]
const PROMOTION_VERIFIED_EXPERIMENTS: Array[String] = [
	"L0_0_STATIONARY_GRAVITY_OFF",
	"L0_1_FREE_FALL",
	"L0_2_BALLISTIC_ZERO_G",
	"L0_3_OBSERVER_AB",
]
const CURRENT_L0_REQUIRED_ARTIFACTS: Array[String] = [
	"manifest.json",
	"process_metadata.json",
	"configuration.json",
	"pre_event_snapshot.jsonl",
	"frames.jsonl",
	"commands.jsonl",
	"applications.jsonl",
	"decisions.jsonl",
	"interventions.jsonl",
	"mechanics.jsonl",
	"events.jsonl",
	"runtime_notes.jsonl",
	"summary.json",
]
const L0_OBSERVER_AB_REQUIRED_ARTIFACTS: Array[String] = [
	"observer_minimal_frames.jsonl",
	"observer_full_frames.jsonl",
	"observer_contact_frames.jsonl",
]
const OUTER_PROCESS_ISOLATION := "outer_parent_reserved_fresh_godot_v1"
const DIRECT_PROCESS_ISOLATION := "direct_in_process_development_only"
const L0_OBSERVER_AB_RECOMPUTER_ID := (
	"sporespore.lab.l0_observer_ab_metric_recomputer.v1")
const L0_OBSERVER_AB_CONTRACT_ID := (
	"sporespore.lab.l0_3.observer_ab_metrics.v1")
const L0_OBSERVER_AB_VALUE_ABSOLUTE_TOLERANCE := 1.0e-7
const L0_OBSERVER_AB_GATE_NUMERIC_ABSOLUTE_TOLERANCE := 1.0e-7
const L0_OBSERVER_AB_STREAM_PROFILES := {
	"frames.jsonl": "full_contacts_v1",
	"observer_minimal_frames.jsonl": "minimal_state_v1",
	"observer_full_frames.jsonl": "full_state_v1",
	"observer_contact_frames.jsonl": "full_contacts_v1",
}
const L0_OBSERVER_AB_METRIC_CONTRACTS := {
	"max_position_delta_m": {
		"unit": "m",
		"left_stream": "observer_minimal_frames.jsonl",
		"right_stream": "observer_full_frames.jsonl",
		"field": "/bodies/body_0/transform/origin",
	},
	"max_velocity_delta_m_s": {
		"unit": "m/s",
		"left_stream": "observer_minimal_frames.jsonl",
		"right_stream": "observer_full_frames.jsonl",
		"field": "/bodies/body_0/linear_velocity",
	},
	"max_contact_profile_position_delta_m": {
		"unit": "m",
		"left_stream": "observer_full_frames.jsonl",
		"right_stream": "observer_contact_frames.jsonl",
		"field": "/bodies/body_0/transform/origin",
	},
	"max_contact_profile_velocity_delta_m_s": {
		"unit": "m/s",
		"left_stream": "observer_full_frames.jsonl",
		"right_stream": "observer_contact_frames.jsonl",
		"field": "/bodies/body_0/linear_velocity",
	},
}


static func validate_bundle(bundle_path: String, options: Dictionary = {}) -> Dictionary:
	# Required-attestation validation is a consuming trust boundary, not just a
	# schema pass. First capture one HMAC-bound, read-once memory image, copy
	# those exact bytes into a private OS-temp directory, and run the existing
	# semantic validator against that copy. This prevents a writer controlling
	# the output store from presenting one file version for hashing and another
	# for metric/provenance reads (the classic ABA/TOCTOU substitution).
	#
	# Structural validation intentionally retains the direct-path implementation
	# because partial/unattested development bundles have no external trust
	# anchor from which an authenticated snapshot could be constructed.
	if String(options.get("attestation_requirement", "structural")) == "required":
		return _validate_required_bundle_consistently(bundle_path, options)
	return _validate_bundle_impl(bundle_path, options)


static func _validate_required_bundle_consistently(
		bundle_path: String,
		options: Dictionary) -> Dictionary:
	var source_absolute := _absolute(bundle_path)
	var source_is_partial := source_absolute.trim_suffix(
		"/").trim_suffix("\\").get_file().ends_with(".partial")
	var snapshot_options: Dictionary = {}
	var test_root := String(options.get(
		"attestation_test_root", "")).strip_edges()
	if not test_root.is_empty():
		snapshot_options["attestation_test_root"] = test_root
	var capture: Dictionary = AttestedBundleSnapshotScript.capture_verified(
		bundle_path, snapshot_options)
	if not bool(capture.get("ok", false)):
		return _authenticated_snapshot_failure(
			bundle_path, capture, "capture")
	var snapshot = capture.get("snapshot")
	if snapshot == null:
		return _authenticated_snapshot_failure(
			bundle_path,
			{
				"failure_code": FailureCodesScript.EVIDENCE_INVALID,
				"message": "Authenticated snapshot capture returned no snapshot object.",
			},
			"capture")

	var parent_result := _reserve_validation_snapshot_parent()
	if not bool(parent_result.get("ok", false)):
		return _authenticated_snapshot_failure(
			bundle_path, parent_result, "temp_reservation")
	var parent_path := String(parent_result["parent_path"])
	var witness: Dictionary = snapshot.publication_witness()
	var materialized: Dictionary = snapshot.materialize_to_empty_temp_parent(
		parent_path, String(witness.get("run_id", "")))
	if not bool(materialized.get("ok", false)):
		var failed_cleanup_ok := _remove_validation_snapshot_tree(parent_path)
		var materialization_failure := materialized.duplicate(true)
		materialization_failure["private_copy_removed"] = failed_cleanup_ok
		if not failed_cleanup_ok:
			materialization_failure["message"] = (
				String(materialized.get(
					"message",
					"Authenticated snapshot materialization failed."))
				+ " Private authenticated validation snapshot cleanup also failed."
			)
		return _authenticated_snapshot_failure(
			bundle_path, materialization_failure, "materialization")

	var private_bundle_path := String(materialized["bundle_path"])
	var private_options := options.duplicate(true)
	# This is trusted wrapper context, not caller authority. It preserves the
	# logical source state after exact bytes move to a run-id-named temp path.
	private_options["_authenticated_source_is_partial"] = source_is_partial
	var result := _validate_bundle_impl(private_bundle_path, private_options)
	if source_is_partial:
		# allow_partial permits forensic inspection before publication; it
		# never turns a source partial path into finalizable/promotable proof.
		result["is_partial"] = true
		result["can_finalize"] = false
		result["can_promote"] = false
	var cleanup_ok := _remove_validation_snapshot_tree(parent_path)
	if not cleanup_ok:
		var cleanup_errors: Array = result.get("errors", []).duplicate(true)
		_add(
			cleanup_errors,
			FailureCodesScript.EVIDENCE_INVALID,
			"/authenticated_snapshot/cleanup",
			"Private authenticated validation snapshot could not be removed.")
		result["errors"] = cleanup_errors
		result["ok"] = false
		result["can_finalize"] = false
		result["can_promote"] = false

	var stats: Dictionary = result.get("stats", {}).duplicate(true)
	stats["authenticated_snapshot"] = {
		"ok": bool(result.get("ok", false)),
		"source_bundle_path": source_absolute,
		"source_is_partial": source_is_partial,
		"run_id": String(witness.get("run_id", "")),
		"algorithm": String(witness.get("algorithm", "")),
		"trust_mode": String(witness.get("trust_mode", "")),
		"key_id": String(witness.get("key_id", "")),
		"receipt_sha256": String(witness.get("receipt_sha256", "")),
		"checksums_sha256": String(capture.get(
			"checksums_sha256", "")),
		"manifest_sha256": String(capture.get(
			"manifest_sha256", "")),
		"artifact_count": int(capture.get("artifact_count", -1)),
		"read_policy": "authenticated_read_once_then_private_validation_v1",
		"private_copy_removed": cleanup_ok,
	}
	result["stats"] = stats
	return result


static func _validate_bundle_impl(
		bundle_path: String,
		options: Dictionary = {}) -> Dictionary:
	var errors: Array = []
	var blockers: Array = []
	var warnings: Array = []
	var stats := {
		"record_counts": {},
		"artifact_count": 0,
		"semantic_verifiers": {},
		"publication_attestation": {},
	}
	var absolute_path := _absolute(bundle_path)
	var is_partial := (
		absolute_path.trim_suffix(
			"/").trim_suffix("\\").get_file().ends_with(".partial")
		or bool(options.get("_authenticated_source_is_partial", false))
	)
	var allow_partial := bool(options.get("allow_partial", false))
	var attestation_requirement := String(
		options.get("attestation_requirement", "structural"))
	if attestation_requirement not in ["structural", "required"]:
		_add(
			errors,
			FailureCodesScript.EVIDENCE_INVALID,
			"/validation_options/attestation_requirement",
			"Attestation requirement must be structural or required.")
	if is_partial and not allow_partial:
		_add(
			errors,
			FailureCodesScript.PARTIAL_RUN_NOT_PROMOTABLE,
			"/",
			"A .partial directory is inspectable but cannot be finalized or promoted.")
	elif is_partial:
		_add(
			blockers,
			FailureCodesScript.PARTIAL_RUN_NOT_PROMOTABLE,
			"/",
			"Structural validation is allowed before rename, but .partial cannot promote.")

	if not DirAccess.dir_exists_absolute(absolute_path):
		_add(errors, FailureCodesScript.ARTIFACT_MISSING, "/", "Bundle directory does not exist.")
		return _result(errors, blockers, warnings, stats, false, false, is_partial)

	var manifest_result := _read_and_validate(
		absolute_path.path_join("manifest.json"),
		SCHEMA_BY_ARTIFACT["manifest.json"])
	_merge_result_errors(errors, manifest_result, "/manifest.json")
	var summary_result := _read_and_validate(
		absolute_path.path_join("summary.json"),
		SCHEMA_BY_ARTIFACT["summary.json"])
	_merge_result_errors(errors, summary_result, "/summary.json")
	var checksums_result := _read_and_validate(
		absolute_path.path_join("checksums.json"),
		SCHEMA_BY_ARTIFACT["checksums.json"])
	_merge_result_errors(errors, checksums_result, "/checksums.json")
	if not manifest_result["ok"] or not summary_result["ok"] or not checksums_result["ok"]:
		return _result(errors, blockers, warnings, stats, false, false, is_partial)

	var manifest: Dictionary = manifest_result["value"]
	var summary: Dictionary = summary_result["value"]
	var checksums: Dictionary = checksums_result["value"]
	var run_id := String(manifest["run_id"])
	_check_run_id(run_id, summary, "/summary.json", errors)
	_check_run_id(run_id, checksums, "/checksums.json", errors)
	_validate_expanded_experiment_integrity(manifest, errors)

	if String(manifest["status"]) != "COMPLETE":
		_add(
			errors,
			FailureCodesScript.MANIFEST_NOT_COMPLETE,
			"/manifest.json/status",
			"Final validation requires manifest status COMPLETE.")

	var declared_required: Array[String] = []
	for artifact_value in manifest.get("required_artifacts", []):
		declared_required.append(String(artifact_value))
	for core_artifact in CORE_ARTIFACTS:
		if not core_artifact in declared_required:
			_add(
				errors,
				FailureCodesScript.ARTIFACT_MISSING,
				"/manifest.json/required_artifacts",
				"Core artifact is not declared: %s" % core_artifact)
	if "checksums.json" in declared_required:
		_add(
			errors,
			FailureCodesScript.ARTIFACT_UNDECLARED,
			"/manifest.json/required_artifacts",
			"checksums.json cannot checksum itself and must not be listed in required_artifacts.")
	_validate_current_l0_artifact_contract(
		manifest, declared_required, errors)

	var artifact_entries: Dictionary = checksums["artifacts"]
	stats["artifact_count"] = artifact_entries.size()
	if int(checksums["artifact_count"]) != artifact_entries.size():
		_add(
			errors,
			FailureCodesScript.LINE_COUNT_MISMATCH,
			"/checksums.json/artifact_count",
			"artifact_count does not equal the artifacts object size.")

	for artifact_name in declared_required:
		if not artifact_entries.has(artifact_name):
			_add(
				errors,
				FailureCodesScript.ARTIFACT_MISSING,
				"/checksums.json/artifacts/%s" % artifact_name,
				"Required artifact is not sealed by checksums.json.")

	var actual_artifacts := _list_immutable_artifacts(absolute_path)
	for actual_name in actual_artifacts:
		if not artifact_entries.has(actual_name):
			_add(
				errors,
				FailureCodesScript.ARTIFACT_UNDECLARED,
				"/%s" % actual_name,
				"Immutable artifact exists but is not sealed by checksums.json.")
	for artifact_name_value in artifact_entries:
		var artifact_name := String(artifact_name_value)
		if artifact_name == "checksums.json":
			_add(
				errors,
				FailureCodesScript.ARTIFACT_UNDECLARED,
				"/checksums.json/artifacts/checksums.json",
				"checksums.json must be outside its own hash domain.")
			continue
		var artifact_path := absolute_path.path_join(artifact_name)
		if not FileAccess.file_exists(artifact_path):
			_add(
				errors,
				FailureCodesScript.ARTIFACT_MISSING,
				"/%s" % artifact_name,
				"Checksummed artifact does not exist.")
			continue
		var entry: Dictionary = artifact_entries[artifact_name_value]
		var actual_sha256 := _sha256_file(artifact_path)
		if actual_sha256 != String(entry["sha256"]):
			_add(
				errors,
				FailureCodesScript.CHECKSUM_MISMATCH,
				"/checksums.json/artifacts/%s/sha256" % artifact_name,
				"Artifact bytes do not match the sealed SHA-256.")
		var actual_bytes := _file_size(artifact_path)
		if actual_bytes != int(entry["bytes"]):
			_add(
				errors,
				FailureCodesScript.BYTE_COUNT_MISMATCH,
				"/checksums.json/artifacts/%s/bytes" % artifact_name,
				"Artifact byte count does not match the sealed count.")
		var kind := String(entry["kind"])
		if kind == "jsonl":
			var stream_result := _validate_jsonl(artifact_path, artifact_name, run_id)
			_merge_result_errors(errors, stream_result, "/%s" % artifact_name)
			var record_count := int(stream_result.get("record_count", 0))
			stats["record_counts"][artifact_name] = record_count
			if entry["records"] == null or int(entry["records"]) != record_count:
				_add(
					errors,
					FailureCodesScript.LINE_COUNT_MISMATCH,
					"/checksums.json/artifacts/%s/records" % artifact_name,
					"JSONL record count does not match checksums.json.")
		elif entry["records"] != null:
			_add(
				errors,
				FailureCodesScript.LINE_COUNT_MISMATCH,
				"/checksums.json/artifacts/%s/records" % artifact_name,
				"Non-JSONL artifacts must record null for records.")
		if kind == "json" \
				and SCHEMA_BY_ARTIFACT.has(artifact_name) \
				and artifact_name not in ["manifest.json", "summary.json"]:
			var object_result := _read_and_validate(
				artifact_path, SCHEMA_BY_ARTIFACT[artifact_name])
			_merge_result_errors(errors, object_result, "/%s" % artifact_name)
			if object_result["ok"]:
				_check_run_id(run_id, object_result["value"], "/%s" % artifact_name, errors)

	_validate_stream_counts(summary, stats["record_counts"], errors)
	_validate_frame_order(absolute_path.path_join("frames.jsonl"), errors)
	for observer_artifact in [
		"observer_minimal_frames.jsonl",
		"observer_full_frames.jsonl",
		"observer_contact_frames.jsonl",
	]:
		var observer_path := absolute_path.path_join(observer_artifact)
		if FileAccess.file_exists(observer_path):
			_validate_frame_order(observer_path, errors)
	_validate_summary_frame_range(
		summary, absolute_path.path_join("frames.jsonl"), errors)
	_validate_note_order(absolute_path.path_join("runtime_notes.jsonl"), errors)
	_validate_cross_record_links(absolute_path, errors)
	_validate_summary_provenance(
		summary, artifact_entries, absolute_path, errors)
	_validate_configuration_integrity(
		absolute_path, manifest, summary, errors)
	_validate_launch_provenance(
		absolute_path, manifest, summary, artifact_entries, errors)
	_validate_source_state_summary(manifest, summary, errors)
	# Checksums, syntax, schemas, record links, configuration, and process
	# provenance establish that the bytes are coherent. These independent
	# passes then establish that every current L0 conclusion actually follows
	# from those bytes instead of trusting runner-authored summary values.
	if errors.is_empty():
		_validate_l0_unary_metrics(
			absolute_path, manifest, summary, stats, errors)
		_validate_l0_observer_ab_metrics(
			absolute_path, manifest, summary, stats, errors)

	if bool(manifest["dirty_worktree"]):
		_add(
			blockers,
			FailureCodesScript.DIRTY_SOURCE_NOT_PROMOTABLE,
			"/manifest.json/dirty_worktree",
			"Dirty-source development evidence may finalize but cannot promote.")
	if String(manifest["execution_mode"]) != "promotion":
		_add(
			blockers,
			FailureCodesScript.EVIDENCE_INVALID,
			"/manifest.json/execution_mode",
			"Only execution_mode=promotion can produce promotion evidence.")
	elif not PROMOTION_VERIFIED_EXPERIMENTS.has(
			String(manifest.get("experiment_id", ""))):
		_add(
			blockers,
			FailureCodesScript.EVIDENCE_INVALID,
			"/manifest.json/experiment_id",
			"No promotion-grade semantic verifier is registered for this experiment.")
	else:
		_validate_live_source_state(manifest, blockers)
	if String(summary["evidence_validity"]) != "valid":
		_add(
			blockers,
			FailureCodesScript.EVIDENCE_INVALID,
			"/summary.json/evidence_validity",
			"Evidence validity must be valid for promotion.")
	if String(summary["promotion"]) != "pass":
		_add(
			blockers,
			FailureCodesScript.EVIDENCE_INVALID,
			"/summary.json/promotion",
			"The preregistered promotion gate did not pass.")
	_validate_publication_attestation(
		absolute_path,
		options,
		attestation_requirement,
		errors,
		blockers,
		stats)

	var structurally_valid := errors.is_empty()
	var can_finalize := structurally_valid and String(manifest["status"]) == "COMPLETE"
	var can_promote := can_finalize and blockers.is_empty() and not is_partial
	return _result(
		errors,
		blockers,
		warnings,
		stats,
		can_finalize,
		can_promote,
		is_partial)


static func _validate_publication_attestation(
		bundle_path: String,
		options: Dictionary,
		requirement: String,
		errors: Array,
		blockers: Array,
		stats: Dictionary) -> void:
	var test_root := String(options.get("attestation_test_root", "")).strip_edges()
	var verification: Dictionary = (
		PublicationAttestationScript.verify_with_test_trust_root(
			bundle_path, test_root)
		if not test_root.is_empty()
		else PublicationAttestationScript.verify_production(bundle_path))
	var safe_result := {
		"ok": bool(verification.get("ok", false)),
		"algorithm": String(verification.get(
			"algorithm", PublicationAttestationScript.ALGORITHM)),
		"trust_mode": String(verification.get(
			"trust_mode",
			"test" if not test_root.is_empty() else "production")),
		"code": String(verification.get(
			"failure_code", verification.get("code", ""))),
		"receipt_path": String(verification.get("receipt_path", "")),
		"receipt_sha256": String(verification.get("receipt_sha256", "")),
		"key_id": String(verification.get("key_id", "")),
		"run_id": String(verification.get("run_id", "")),
		"checksums_sha256": String(verification.get(
			"checksums_sha256", "")),
		"manifest_sha256": String(verification.get(
			"manifest_sha256", "")),
		"artifact_count": int(verification.get(
			"artifact_count", -1)),
		"attested_utc": String(verification.get("attested_utc", "")),
	}
	stats["publication_attestation"] = safe_result
	if bool(verification.get("ok", false)):
		if String(verification.get("trust_mode", "")) != "production":
			_add(
				blockers,
				FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
				"/publication_attestation/trust_mode",
				"Test-root publication receipts are valid test evidence but can never promote.")
		return

	var failure_code := String(verification.get(
		"failure_code",
		verification.get(
			"code",
			FailureCodesScript.PUBLICATION_RECEIPT_INVALID)))
	var message := String(verification.get(
		"message", "Detached publication attestation verification failed."))
	if (
		failure_code == FailureCodesScript.PUBLICATION_RECEIPT_MISSING
		and requirement == "structural"
	):
		_add(
			blockers,
			failure_code,
			"/publication_attestation",
			"%s Structural inspection may continue, but publication and promotion are blocked."
				% message)
		return
	_add(
		errors,
		failure_code,
		"/publication_attestation",
		message)


static func _validate_l0_unary_metrics(
		directory: String,
		manifest: Dictionary,
		summary: Dictionary,
		stats: Dictionary,
		errors: Array) -> void:
	var experiment_id := String(manifest.get("experiment_id", ""))
	if not L0MetricRecomputerScript.supports_experiment(experiment_id):
		return
	var streams: Dictionary = {}
	for stream_name in [
		"frames.jsonl",
		"commands.jsonl",
		"applications.jsonl",
		"interventions.jsonl",
		"runtime_notes.jsonl",
	]:
		var stream_path := directory.path_join(stream_name)
		if not FileAccess.file_exists(stream_path):
			continue
		var parsed := _read_jsonl_values(stream_path)
		if not bool(parsed.get("ok", false)):
			_add(
				errors,
				FailureCodesScript.JSON_PARSE_FAILED,
				"/%s" % stream_name,
				"Unary metric recomputation could not parse the sealed stream.")
			return
		streams[stream_name] = parsed["values"]
	var semantic_result: Dictionary = L0MetricRecomputerScript.verify(
		manifest, summary, streams)
	stats["semantic_verifiers"][
		String(semantic_result.get("recomputer_id", "unknown"))] = {
			"ok": bool(semantic_result.get("ok", false)),
			"contract_id": semantic_result.get("contract_id"),
			"analytic_contract_version":
				semantic_result.get("analytic_contract_version"),
			"value_absolute_tolerance":
				semantic_result.get("value_absolute_tolerance"),
			"gate_numeric_absolute_tolerance":
				semantic_result.get("gate_numeric_absolute_tolerance"),
			"verified_metric_count":
				int(semantic_result.get("metric_checks", []).size()),
			# Keep the independent witness inspectable. These values are all
			# derived from already-sealed public evidence; they contain no
			# hidden configuration or trust material.
			"metric_checks":
				semantic_result.get("metric_checks", []).duplicate(true),
			"semantic_errors":
				semantic_result.get("errors", []).duplicate(true),
			"recomputed_physical_gate":
				semantic_result.get("recomputed_physical_gate", {}).duplicate(
					true),
		}
	if bool(semantic_result.get("ok", false)):
		return
	for semantic_error_value in semantic_result.get("errors", []):
		var semantic_error: Dictionary = semantic_error_value
		_add(
			errors,
			FailureCodesScript.EVIDENCE_INVALID,
			String(semantic_error.get("path", "/summary.json")),
			"Independent unary metric recomputation [%s]: %s" % [
				String(semantic_error.get("code", "SEMANTIC_MISMATCH")),
				String(semantic_error.get(
					"message", "The stored conclusion did not reproduce.")),
			])


static func _validate_l0_observer_ab_metrics(
		directory: String,
		manifest: Dictionary,
		summary: Dictionary,
		stats: Dictionary,
		errors: Array) -> void:
	if String(manifest.get("experiment_id", "")) != "L0_3_OBSERVER_AB":
		return
	var error_count_before := errors.size()
	var run_id := String(manifest.get("run_id", ""))
	var frame_count := int(summary.get("frame_count", -1))
	var expanded_value: Variant = manifest.get("expanded_parameters")
	var preregistered_frame_count := -1
	if typeof(expanded_value) == TYPE_DICTIONARY:
		preregistered_frame_count = int(
			(expanded_value as Dictionary).get("duration_ticks", -2)) + 1
	if frame_count <= 0:
		_l03_add(
			errors,
			"FRAME_COUNT_INVALID",
			"/summary.json/frame_count",
			"Observer A/B evidence requires one or more complete frames.")
	elif frame_count != preregistered_frame_count:
		_l03_add(
			errors,
			"FRAME_COUNT_CONTRACT_MISMATCH",
			"/summary.json/frame_count",
			"Observer A/B evidence must contain duration_ticks + 1 frames (%d), not %d." % [
				preregistered_frame_count,
				frame_count,
			])

	var streams: Dictionary = {}
	for stream_name_value in L0_OBSERVER_AB_STREAM_PROFILES:
		var stream_name := String(stream_name_value)
		var stream_path := directory.path_join(stream_name)
		var parsed := _read_jsonl_values(stream_path)
		if not bool(parsed.get("ok", false)):
			_l03_add(
				errors,
				"OBSERVER_STREAM_UNREADABLE",
				"/%s" % stream_name,
				"Required observer A/B stream cannot be parsed.")
			continue
		var values: Array = parsed.get("values", [])
		streams[stream_name] = values
		_l03_validate_stream(
			stream_name,
			values,
			String(L0_OBSERVER_AB_STREAM_PROFILES[stream_name_value]),
			run_id,
			frame_count,
			int(manifest.get("physics_ticks_per_second", -1)),
			errors)

	var stream_shapes_available := (
		streams.size() == L0_OBSERVER_AB_STREAM_PROFILES.size())
	if stream_shapes_available:
		for stream_name_value in L0_OBSERVER_AB_STREAM_PROFILES:
			var stream_name := String(stream_name_value)
			if (
				not streams.has(stream_name)
				or (streams[stream_name] as Array).size() != frame_count
			):
				stream_shapes_available = false
				break
	if stream_shapes_available:
		_l03_validate_cross_stream_identity(
			streams, frame_count, errors)
	var streams_valid := errors.size() == error_count_before
	_l03_validate_no_control_contract(
		directory, manifest, run_id, frame_count, errors)

	var recomputed_metrics: Dictionary = {}
	if streams_valid:
		for metric_id_value in L0_OBSERVER_AB_METRIC_CONTRACTS:
			var metric_id := String(metric_id_value)
			var contract: Dictionary = L0_OBSERVER_AB_METRIC_CONTRACTS[
				metric_id_value]
			recomputed_metrics[metric_id] = _l03_max_pairwise_distance(
				streams[String(contract["left_stream"])],
				streams[String(contract["right_stream"])],
				String(contract["field"]))

	var metric_checks := _l03_validate_metric_contract(
		summary,
		run_id,
		frame_count,
		recomputed_metrics,
		errors)
	var gate_parameters := _l03_validate_gate_parameters(manifest, errors)
	var recomputed_gate: Dictionary = {}
	if (
		recomputed_metrics.size()
			== L0_OBSERVER_AB_METRIC_CONTRACTS.size()
		and gate_parameters.size()
			== L0_OBSERVER_AB_METRIC_CONTRACTS.size()
	):
		recomputed_gate = GateEvaluatorScript.evaluate_l0(
			"L0_3_OBSERVER_AB",
			recomputed_metrics,
			gate_parameters)
		_l03_validate_summary_semantics(
			summary, recomputed_gate, errors)
		_l03_validate_reporting_mirrors(
			directory,
			manifest,
			summary,
			recomputed_metrics,
			recomputed_gate,
			run_id,
			frame_count,
			errors)

	var verifier_ok := errors.size() == error_count_before
	stats["semantic_verifiers"][L0_OBSERVER_AB_RECOMPUTER_ID] = {
		"ok": verifier_ok,
		"contract_id": L0_OBSERVER_AB_CONTRACT_ID,
		"analytic_contract_version": 1,
		"value_absolute_tolerance":
			L0_OBSERVER_AB_VALUE_ABSOLUTE_TOLERANCE,
		"gate_numeric_absolute_tolerance":
			L0_OBSERVER_AB_GATE_NUMERIC_ABSOLUTE_TOLERANCE,
		"verified_metric_count": metric_checks.size(),
		"verified_stream_count": streams.size(),
		"primary_contact_identity_verified": streams_valid,
	}


static func _l03_validate_stream(
		stream_name: String,
		frames: Array,
		expected_profile_id: String,
		run_id: String,
		expected_frame_count: int,
		physics_ticks_per_second: int,
		errors: Array) -> void:
	if frames.size() != expected_frame_count:
		_l03_add(
			errors,
			"OBSERVER_STREAM_FRAME_COUNT_MISMATCH",
			"/%s" % stream_name,
			"Stream has %d frames; the sealed summary requires %d." % [
				frames.size(),
				expected_frame_count,
			])
		return
	var previous_callback_sequence := -1
	for frame_index in frames.size():
		var frame_value: Variant = frames[frame_index]
		var frame_path := "/%s/%d" % [stream_name, frame_index]
		if typeof(frame_value) != TYPE_DICTIONARY:
			_l03_add(
				errors,
				"OBSERVER_FRAME_INVALID",
				frame_path,
				"Observer frame must be an object.")
			continue
		var frame: Dictionary = frame_value
		if String(frame.get("run_id", "")) != run_id:
			_l03_add(
				errors,
				"OBSERVER_FRAME_RUN_ID_MISMATCH",
				"%s/run_id" % frame_path,
				"Observer frame does not belong to the sealed run.")
		if int(frame.get("frame_id", -1)) != frame_index:
			_l03_add(
				errors,
				"OBSERVER_FRAME_SEQUENCE_MISMATCH",
				"%s/frame_id" % frame_path,
				"Observer frame IDs must be contiguous from zero.")
		var expected_time := (
			float(frame_index) / float(physics_ticks_per_second)
			if physics_ticks_per_second > 0
			else INF)
		if (
			int(frame.get("physics_step_id", -1)) != frame_index
			or int(frame.get("capture_epoch", -1)) != frame_index
			or String(frame.get("sample_phase", ""))
				!= "integrate_callback"
			or String(frame.get("experiment_phase", "")) != "MEASURE"
			or int(frame.get("release_frame_id", -1)) != 0
			or not is_finite(expected_time)
			or absf(
				float(frame.get("physics_time_s", INF))
					- expected_time) > 1.0e-9
		):
			_l03_add(
				errors,
				"OBSERVER_CAPTURE_TIMELINE_MISMATCH",
				frame_path,
				"Observer capture must map frame N to physics step/epoch N at N / physics_ticks_per_second.")
		if not bool(frame.get("finite", false)):
			_l03_add(
				errors,
				"OBSERVER_FRAME_NONFINITE",
				"%s/finite" % frame_path,
				"Non-finite observer state cannot support parity evidence.")
		var contacts_value: Variant = frame.get("contacts")
		var availability: Dictionary = frame.get("availability", {})
		if (
			typeof(contacts_value) != TYPE_ARRAY
			or not (contacts_value as Array).is_empty()
			or int(availability.get("contact_count", -1)) != 0
		):
			_l03_add(
				errors,
				"COLLISION_FREE_SCOPE_VIOLATED",
				"%s/contacts" % frame_path,
				"L0.3 is preregistered as collision-free observer parity; every arm must prove zero contacts.")
		if (
			availability.get("required_body_ids", []) != ["body_0"]
			or int(availability.get("captured_body_count", -1)) != 1
			or not (availability.get(
				"invalid_reasons", []) as Array).is_empty()
		):
			_l03_add(
				errors,
				"OBSERVER_CAPTURE_AVAILABILITY_MISMATCH",
				"%s/availability" % frame_path,
				"Each observer frame must contain exactly one valid required body_0 capture.")
		var bodies_value: Variant = frame.get("bodies")
		if (
			typeof(bodies_value) != TYPE_DICTIONARY
			or (bodies_value as Dictionary).size() != 1
			or not (bodies_value as Dictionary).has("body_0")
		):
			_l03_add(
				errors,
				"OBSERVER_BODY_SET_MISMATCH",
				"%s/bodies" % frame_path,
				"L0.3 requires exactly the preregistered body_0 sample.")
			continue
		var body: Dictionary = (bodies_value as Dictionary)["body_0"]
		var body_path := "%s/bodies/body_0" % frame_path
		var callback_sequence := int(body.get(
			"body_callback_sequence", -1))
		if callback_sequence <= previous_callback_sequence:
			_l03_add(
				errors,
				"OBSERVER_CALLBACK_SEQUENCE_STALE",
				"%s/body_callback_sequence" % body_path,
				"Body callback sequence must advance on every captured physics step.")
		previous_callback_sequence = callback_sequence
		if (
			String(body.get("body_id", "")) != "body_0"
			or String(body.get("observer_profile_id", ""))
				!= expected_profile_id
			or String(body.get("observer_adapter_id", ""))
				!= "rigid_body_integrate_forces_v1"
		):
			_l03_add(
				errors,
				"OBSERVER_ARM_IDENTITY_MISMATCH",
				body_path,
				"Frame body does not carry the preregistered observer profile and adapter.")
		if not bool(body.get("finite", false)):
			_l03_add(
				errors,
				"OBSERVER_BODY_NONFINITE",
				"%s/finite" % body_path,
				"Non-finite body state cannot support parity evidence.")
		if (
			int(body.get("physics_step_id", -1))
				!= int(frame.get("physics_step_id", -2))
			or int(body.get("capture_epoch", -1))
				!= int(frame.get("capture_epoch", -2))
			or String(body.get("sample_phase", ""))
				!= String(frame.get("sample_phase", ""))
		):
			_l03_add(
				errors,
				"OBSERVER_FRAME_BODY_IDENTITY_MISMATCH",
				body_path,
				"Body callback identity does not agree with its containing frame.")
		for field in [
			"/bodies/body_0/transform/origin",
			"/bodies/body_0/linear_velocity",
		]:
			if not _json_vec3(_resolve_json_pointer(frame, field)).is_finite():
				_l03_add(
					errors,
					"OBSERVER_VECTOR_NONFINITE",
					"%s%s" % [frame_path, field],
					"Required observer comparison vector is absent or non-finite.")


static func _l03_validate_cross_stream_identity(
		streams: Dictionary,
		frame_count: int,
		errors: Array) -> void:
	var identity_fields := [
		"frame_id",
		"physics_step_id",
		"capture_epoch",
		"physics_time_s",
		"sample_phase",
		"experiment_phase",
		"release_frame_id",
	]
	var body_identity_fields := [
		"physics_step_id",
		"body_callback_sequence",
		"capture_epoch",
		"sample_phase",
		"body_id",
		"part_index",
	]
	var reference_frames: Array = streams[
		"observer_minimal_frames.jsonl"]
	for frame_index in frame_count:
		var reference: Dictionary = reference_frames[frame_index]
		var reference_body: Dictionary = reference["bodies"]["body_0"]
		for stream_name in [
			"observer_full_frames.jsonl",
			"observer_contact_frames.jsonl",
		]:
			var compared: Dictionary = streams[stream_name][frame_index]
			var compared_body: Dictionary = compared["bodies"]["body_0"]
			var matches := true
			for field in identity_fields:
				matches = matches and reference.get(field) == compared.get(field)
			for field in body_identity_fields:
				matches = (
					matches
					and reference_body.get(field) == compared_body.get(field))
			if not matches:
				_l03_add(
					errors,
					"OBSERVER_ARM_STRUCTURAL_IDENTITY_MISMATCH",
					"/%s/%d" % [stream_name, frame_index],
					"Observer arms do not describe the same physics callback.")
		var primary: Dictionary = streams["frames.jsonl"][frame_index]
		var contact: Dictionary = streams[
			"observer_contact_frames.jsonl"][frame_index]
		if CanonicalJsonScript.sha256(primary) \
				!= CanonicalJsonScript.sha256(contact):
			_l03_add(
				errors,
				"PRIMARY_CONTACT_STREAM_MISMATCH",
				"/frames.jsonl/%d" % frame_index,
				"Primary L0.3 trajectory must be byte-semantically identical to the full-contact observer arm.")


static func _l03_max_pairwise_distance(
		left_frames: Array,
		right_frames: Array,
		field: String) -> float:
	var maximum := 0.0
	for frame_index in left_frames.size():
		var left := _json_vec3(
			_resolve_json_pointer(left_frames[frame_index], field))
		var right := _json_vec3(
			_resolve_json_pointer(right_frames[frame_index], field))
		maximum = maxf(maximum, left.distance_to(right))
	return maximum


static func _l03_validate_no_control_contract(
		directory: String,
		manifest: Dictionary,
		run_id: String,
		frame_count: int,
		errors: Array) -> void:
	var expanded: Dictionary = manifest.get("expanded_parameters", {})
	if String(expanded.get("controller_id", "")) != "none":
		_l03_add(
			errors,
			"CONTROLLER_CONTRACT_MISMATCH",
			"/manifest.json/expanded_parameters/controller_id",
			"L0.3 observer parity is preregistered with controller_id=none.")
	var commands_read := _read_jsonl_values(
		directory.path_join("commands.jsonl"))
	var commands: Array = commands_read.get("values", [])
	if (
		not bool(commands_read.get("ok", false))
		or commands.size() != maxi(frame_count - 1, 0)
	):
		_l03_add(
			errors,
			"NO_CONTROL_COMMAND_COUNT_MISMATCH",
			"/commands.jsonl",
			"L0.3 requires exactly one sealed NONE command per frame transition.")
	else:
		for transition_index in commands.size():
			var envelope: Dictionary = commands[transition_index]
			var payload: Dictionary = envelope.get("payload", {})
			if (
				String(payload.get("run_id", "")) != run_id
				or int(payload.get("command_id", -1))
					!= transition_index
				or int(payload.get("source_frame_id", -1))
					!= transition_index
				or not _is_transition(
					payload.get("applied_transition", []),
					transition_index)
				or String(payload.get("mode", "")) != "NONE"
				or not (payload.get(
					"joint_commands", []) as Array).is_empty()
				or not (payload.get(
					"intervention_operation_ids", []) as Array).is_empty()
			):
				_l03_add(
					errors,
					"NO_CONTROL_COMMAND_MISMATCH",
					"/commands.jsonl/%d" % transition_index,
					"L0.3 command ledger contains control or does not map exactly to its frame transition.")
	for empty_stream in [
		"applications.jsonl",
		"decisions.jsonl",
		"interventions.jsonl",
	]:
		var read := _read_jsonl_values(
			directory.path_join(empty_stream))
		if (
			not bool(read.get("ok", false))
			or not (read.get("values", []) as Array).is_empty()
		):
			_l03_add(
				errors,
				"NO_CONTROL_LEDGER_NOT_EMPTY",
				"/%s" % empty_stream,
				"L0.3 observer-only evidence forbids applications, decisions, and interventions.")


static func _l03_validate_reporting_mirrors(
		directory: String,
		manifest: Dictionary,
		summary: Dictionary,
		recomputed_metrics: Dictionary,
		recomputed_gate: Dictionary,
		run_id: String,
		frame_count: int,
		errors: Array) -> void:
	var gates: Dictionary = summary.get("gate_results", {})
	var source_gate: Dictionary = gates.get("source_state", {})
	var events_read := _read_jsonl_values(
		directory.path_join("events.jsonl"))
	var events: Array = events_read.get("values", [])
	if not bool(events_read.get("ok", false)) or events.size() != 1:
		_l03_add(
			errors,
			"PROMOTION_EVENT_SET_MISMATCH",
			"/events.jsonl",
			"Completed collision-free L0.3 evidence requires exactly one promotion-decision event.")
	else:
		var event: Dictionary = events[0]
		var expected_event_evidence := {
			"physical_gate_pass": bool(recomputed_gate.get(
				"pass", false)),
			"source_state_gate_pass": bool(source_gate.get(
				"pass", false)),
		}
		if (
			String(event.get("run_id", "")) != run_id
			or int(event.get("event_sequence", -1)) != 0
			or int(event.get("frame_id", -1))
				!= frame_count - 1
			or String(event.get("event", ""))
				!= "PROMOTION_DECISION"
			or String(event.get("subject_id", ""))
				!= "L0_3_OBSERVER_AB"
			or int(event.get("detector_local_ordinal", -1)) != 0
			or CanonicalJsonScript.sha256(
				event.get("evidence", {}))
				!= CanonicalJsonScript.sha256(
					expected_event_evidence)
		):
			_l03_add(
				errors,
				"PROMOTION_EVENT_MISMATCH",
				"/events.jsonl/0",
				"Promotion event does not mirror recomputed physical and source-state gates.")

	var notes_read := _read_jsonl_values(
		directory.path_join("runtime_notes.jsonl"))
	var notes: Array = notes_read.get("values", [])
	if not bool(notes_read.get("ok", false)) or notes.size() != 2:
		_l03_add(
			errors,
			"RUNTIME_NOTE_SET_MISMATCH",
			"/runtime_notes.jsonl",
			"Completed L0.3 evidence requires exactly RUN_STARTED and RUN_RESULT notes.")
		return
	var started: Dictionary = notes[0]
	var expected_started_evidence := {
		"experiment_id": "L0_3_OBSERVER_AB",
		"expanded_spec_sha256": manifest.get(
			"expanded_spec_sha256"),
	}
	if (
		int(started.get("note_sequence", -1)) != 0
		or started.get("frame_id") != null
		or String(started.get("source", "")) != "lab_runner"
		or String(started.get("severity", "")) != "info"
		or String(started.get("code", "")) != "RUN_STARTED"
		or CanonicalJsonScript.sha256(started.get("evidence", {}))
			!= CanonicalJsonScript.sha256(
				expected_started_evidence)
	):
		_l03_add(
			errors,
			"RUN_STARTED_NOTE_MISMATCH",
			"/runtime_notes.jsonl/0",
			"RUN_STARTED note does not bind the exact experiment and expanded-spec hash.")
	var result_note: Dictionary = notes[1]
	var result_evidence: Dictionary = result_note.get("evidence", {})
	var expected_result_keys: Array = [
		"experiment_id",
		"finite",
		"gate",
	]
	expected_result_keys.append_array(
		L0_OBSERVER_AB_METRIC_CONTRACTS.keys())
	expected_result_keys.sort()
	var actual_result_keys: Array = result_evidence.keys()
	actual_result_keys.sort()
	var result_valid := (
		int(result_note.get("note_sequence", -1)) == 1
		and result_note.get("frame_id") == null
		and String(result_note.get("source", "")) == "lab_runner"
		and String(result_note.get("code", "")) == "RUN_RESULT"
		and String(result_evidence.get("experiment_id", ""))
			== "L0_3_OBSERVER_AB"
		and bool(result_evidence.get("finite", false))
		and actual_result_keys == expected_result_keys
		and result_evidence.get("gate") is Dictionary
		and _l03_physical_gates_match(
			result_evidence.get("gate", {}), recomputed_gate))
	for metric_id_value in L0_OBSERVER_AB_METRIC_CONTRACTS:
		var metric_id := String(metric_id_value)
		var mirrored_value: Variant = result_evidence.get(metric_id)
		result_valid = (
			result_valid
			and typeof(mirrored_value) in [TYPE_INT, TYPE_FLOAT]
			and is_finite(float(mirrored_value))
			and recomputed_metrics.has(metric_id)
			and absf(
				float(mirrored_value)
					- float(recomputed_metrics.get(
						metric_id, INF)))
				<= L0_OBSERVER_AB_VALUE_ABSOLUTE_TOLERANCE)
	var expected_severity := (
		"info"
		if bool(recomputed_gate.get("pass", false))
		else "warning")
	result_valid = result_valid and String(result_note.get(
		"severity", "")) == expected_severity
	if not result_valid:
		_l03_add(
			errors,
			"RUN_RESULT_NOTE_MISMATCH",
			"/runtime_notes.jsonl/1",
			"RUN_RESULT note does not mirror all recomputed metrics, finiteness, and the physical gate.")


static func _l03_validate_metric_contract(
		summary: Dictionary,
		run_id: String,
		frame_count: int,
		recomputed_metrics: Dictionary,
		errors: Array) -> Array:
	var checks: Array = []
	var metrics_value: Variant = summary.get("metrics")
	if typeof(metrics_value) != TYPE_ARRAY:
		_l03_add(
			errors,
			"METRIC_SET_MISMATCH",
			"/summary.json/metrics",
			"L0.3 summary must contain its four comparison metrics.")
		return checks
	var metrics: Array = metrics_value
	var metrics_by_id: Dictionary = {}
	for metric_index in metrics.size():
		var metric_value: Variant = metrics[metric_index]
		if typeof(metric_value) != TYPE_DICTIONARY:
			continue
		var metric: Dictionary = metric_value
		var metric_id := String(metric.get("metric_id", ""))
		if metrics_by_id.has(metric_id):
			_l03_add(
				errors,
				"DUPLICATE_METRIC_ID",
				"/summary.json/metrics/%d/metric_id" % metric_index,
				"L0.3 comparison metric IDs must be unique.")
		else:
			metrics_by_id[metric_id] = {
				"index": metric_index,
				"metric": metric,
			}
	for actual_id_value in metrics_by_id:
		var actual_id := String(actual_id_value)
		if not L0_OBSERVER_AB_METRIC_CONTRACTS.has(actual_id):
			_l03_add(
				errors,
				"UNEXPECTED_METRIC_ID",
				"/summary.json/metrics/%d/metric_id"
					% int(metrics_by_id[actual_id]["index"]),
				"L0.3 summary contains a metric outside its versioned contract.")
	for expected_id_value in L0_OBSERVER_AB_METRIC_CONTRACTS:
		var metric_id := String(expected_id_value)
		if not metrics_by_id.has(metric_id):
			_l03_add(
				errors,
				"METRIC_SET_MISMATCH",
				"/summary.json/metrics",
				"Required L0.3 metric is missing: %s." % metric_id)
			continue
		var entry: Dictionary = metrics_by_id[metric_id]
		var metric_index := int(entry["index"])
		var metric: Dictionary = entry["metric"]
		var path := "/summary.json/metrics/%d" % metric_index
		var contract: Dictionary = L0_OBSERVER_AB_METRIC_CONTRACTS[
			expected_id_value]
		var expected_keys := [
			"aggregation_id",
			"aggregation_version",
			"availability",
			"metric_id",
			"recompute_absolute_tolerance",
			"source_operands",
			"target_value",
			"unit",
			"value",
		]
		var actual_keys: Array = metric.keys()
		actual_keys.sort()
		if actual_keys != expected_keys:
			_l03_add(
				errors,
				"METRIC_CONTRACT_MISMATCH",
				path,
				"Metric fields do not match the exact comparison-metric contract.")
		for field_pair in [
			["unit", contract["unit"]],
			["availability", "derived"],
			["aggregation_id", "max_pairwise_vec3_distance_v1"],
			["aggregation_version", 1],
			["target_value", 0.0],
			[
				"recompute_absolute_tolerance",
				L0_OBSERVER_AB_VALUE_ABSOLUTE_TOLERANCE,
			],
		]:
			if metric.get(String(field_pair[0])) != field_pair[1]:
				_l03_add(
					errors,
					"METRIC_CONTRACT_MISMATCH",
					"%s/%s" % [path, String(field_pair[0])],
					"Metric provenance field differs from the versioned L0.3 contract.")
		var expected_operands := [
			{
				"stream": String(contract["left_stream"]),
				"frame_range": [0, frame_count - 1],
				"field": String(contract["field"]),
				"run_id": run_id,
			},
			{
				"stream": String(contract["right_stream"]),
				"frame_range": [0, frame_count - 1],
				"field": String(contract["field"]),
				"run_id": run_id,
			},
		]
		if CanonicalJsonScript.sha256(metric.get("source_operands", [])) \
				!= CanonicalJsonScript.sha256(expected_operands):
			_l03_add(
				errors,
				"METRIC_OPERAND_CONTRACT_MISMATCH",
				"%s/source_operands" % path,
				(
					"Metric operands must cover the exact preregistered "
					+ "streams, field, run, and complete frame range."))
		if not recomputed_metrics.has(metric_id):
			_l03_add(
				errors,
				"METRIC_RECOMPUTATION_UNAVAILABLE",
				"%s/value" % path,
				"Metric could not be rebuilt from the sealed observer arms.")
			continue
		var recorded_value: Variant = metric.get("value")
		if (
			typeof(recorded_value) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(recorded_value))
		):
			_l03_add(
				errors,
				"METRIC_VALUE_INVALID",
				"%s/value" % path,
				"Recorded comparison metric must be finite.")
			continue
		var recomputed := float(recomputed_metrics[metric_id])
		var tolerance := maxf(
			L0_OBSERVER_AB_VALUE_ABSOLUTE_TOLERANCE,
			absf(recomputed) * 1.0e-12)
		var matches := absf(float(recorded_value) - recomputed) <= tolerance
		checks.append({
			"metric_id": metric_id,
			"recorded": float(recorded_value),
			"recomputed": recomputed,
			"absolute_tolerance": tolerance,
			"pass": matches,
		})
		if not matches:
			_l03_add(
				errors,
				"METRIC_VALUE_MISMATCH",
				"%s/value" % path,
				"Stored comparison metric does not reproduce from the sealed observer arms.")
	if metrics.size() != L0_OBSERVER_AB_METRIC_CONTRACTS.size():
		_l03_add(
			errors,
			"METRIC_SET_MISMATCH",
			"/summary.json/metrics",
			"L0.3 requires exactly four metrics, without omissions or extras.")
	return checks


static func _l03_validate_gate_parameters(
		manifest: Dictionary,
		errors: Array) -> Dictionary:
	var expanded_value: Variant = manifest.get("expanded_parameters")
	if typeof(expanded_value) != TYPE_DICTIONARY:
		_l03_add(
			errors,
			"GATE_PARAMETERS_MISSING",
			"/manifest.json/expanded_parameters",
			"Manifest does not seal the expanded L0.3 experiment.")
		return {}
	var gate_value: Variant = (expanded_value as Dictionary).get(
		"gate_parameters")
	if typeof(gate_value) != TYPE_DICTIONARY:
		_l03_add(
			errors,
			"GATE_PARAMETERS_MISSING",
			"/manifest.json/expanded_parameters/gate_parameters",
			"Expanded L0.3 experiment does not seal its gate tolerances.")
		return {}
	var gates: Dictionary = gate_value
	var expected_ids: Array = L0_OBSERVER_AB_METRIC_CONTRACTS.keys()
	expected_ids.sort()
	var actual_ids: Array = gates.keys()
	actual_ids.sort()
	if actual_ids != expected_ids:
		_l03_add(
			errors,
			"GATE_PARAMETER_SET_MISMATCH",
			"/manifest.json/expanded_parameters/gate_parameters",
			"L0.3 gate parameters must exactly match all four comparison metrics.")
		return {}
	for metric_id_value in expected_ids:
		var metric_id := String(metric_id_value)
		var value: Variant = gates[metric_id_value]
		if (
			typeof(value) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(value))
			or float(value) < 0.0
		):
			_l03_add(
				errors,
				"GATE_PARAMETER_INVALID",
				"/manifest.json/expanded_parameters/gate_parameters/%s"
					% metric_id,
				"L0.3 tolerance must be a finite non-negative number.")
	return gates.duplicate(true)


static func _l03_validate_summary_semantics(
		summary: Dictionary,
		recomputed_gate: Dictionary,
		errors: Array) -> void:
	var gates_value: Variant = summary.get("gate_results")
	if typeof(gates_value) != TYPE_DICTIONARY:
		_l03_add(
			errors,
			"SUMMARY_GATE_RESULTS_MISSING",
			"/summary.json/gate_results",
			"Summary lacks its prerequisite and physical gates.")
		return
	var gates: Dictionary = gates_value
	var physical_value: Variant = gates.get("physical")
	var configuration_value: Variant = gates.get("configuration")
	var source_value: Variant = gates.get("source_state")
	if typeof(physical_value) != TYPE_DICTIONARY:
		_l03_add(
			errors,
			"SUMMARY_PHYSICAL_GATE_MISSING",
			"/summary.json/gate_results/physical",
			"Summary lacks the physical comparison gate.")
	elif not _l03_physical_gates_match(
			physical_value as Dictionary, recomputed_gate):
		_l03_add(
			errors,
			"PHYSICAL_GATE_RESULT_MISMATCH",
			"/summary.json/gate_results/physical",
			"Stored L0.3 physical gate does not match the recomputed metrics and sealed tolerances.")
	if typeof(configuration_value) != TYPE_DICTIONARY:
		_l03_add(
			errors,
			"SUMMARY_CONFIGURATION_GATE_MISSING",
			"/summary.json/gate_results/configuration",
			"Summary lacks the independently checked configuration gate.")
		return
	if typeof(source_value) != TYPE_DICTIONARY:
		_l03_add(
			errors,
			"SUMMARY_SOURCE_GATE_MISSING",
			"/summary.json/gate_results/source_state",
			"Summary lacks the independently checked source-state gate.")
		return
	var configuration_pass := bool(
		(configuration_value as Dictionary).get("pass", false))
	var source_pass := bool((source_value as Dictionary).get("pass", false))
	var physical_pass := bool(recomputed_gate.get("pass", false)) \
		and configuration_pass
	var expected_hypothesis := (
		("supported" if physical_pass else "contradicted")
			if configuration_pass
			else "inconclusive")
	var expected_promotion := (
		"pass"
			if physical_pass and source_pass
			else ("not_evaluated" if not source_pass else "fail"))
	if String(summary.get("hypothesis_result", "")) != expected_hypothesis:
		_l03_add(
			errors,
			"SUMMARY_HYPOTHESIS_RESULT_MISMATCH",
			"/summary.json/hypothesis_result",
			"Stored hypothesis result does not follow from the recomputed physical and configuration gates.")
	if String(summary.get("promotion", "")) != expected_promotion:
		_l03_add(
			errors,
			"SUMMARY_PROMOTION_MISMATCH",
			"/summary.json/promotion",
			"Stored promotion does not follow from recomputed physics and prerequisite gates.")
	if (
		String(summary.get("termination", "")) != "completed"
		or String(summary.get("evidence_validity", "")) != "valid"
		or not (summary.get("failure_codes", []) as Array).is_empty()
	):
		_l03_add(
			errors,
			"SUMMARY_COMPLETION_STATE_MISMATCH",
			"/summary.json",
			"A finalized L0.3 result must be completed, valid, and free of failure codes.")


static func _l03_physical_gates_match(
		recorded: Dictionary,
		recomputed: Dictionary) -> bool:
	for field in ["gate_id", "pass", "reason"]:
		if recorded.get(field) != recomputed.get(field):
			return false
	var recorded_checks: Variant = recorded.get("checks")
	var recomputed_checks: Variant = recomputed.get("checks")
	if (
		typeof(recorded_checks) != TYPE_ARRAY
		or typeof(recomputed_checks) != TYPE_ARRAY
		or (recorded_checks as Array).size()
			!= (recomputed_checks as Array).size()
	):
		return false
	for check_index in (recomputed_checks as Array).size():
		var recorded_value: Variant = recorded_checks[check_index]
		var recomputed_value: Variant = recomputed_checks[check_index]
		if (
			typeof(recorded_value) != TYPE_DICTIONARY
			or typeof(recomputed_value) != TYPE_DICTIONARY
		):
			return false
		var recorded_check: Dictionary = recorded_value
		var recomputed_check: Dictionary = recomputed_value
		for field in ["metric_id", "pass", "operator", "reason"]:
			if recorded_check.get(field) != recomputed_check.get(field):
				return false
		for field in ["observed", "limit"]:
			var recorded_number: Variant = recorded_check.get(field)
			var recomputed_number: Variant = recomputed_check.get(field)
			if (
				typeof(recorded_number) not in [TYPE_INT, TYPE_FLOAT]
				or typeof(recomputed_number) not in [TYPE_INT, TYPE_FLOAT]
				or not is_finite(float(recorded_number))
				or not is_finite(float(recomputed_number))
				or absf(
					float(recorded_number) - float(recomputed_number))
					> L0_OBSERVER_AB_GATE_NUMERIC_ABSOLUTE_TOLERANCE
			):
				return false
	return true


static func _l03_add(
		errors: Array,
		semantic_code: String,
		path: String,
		message: String) -> void:
	_add(
		errors,
		FailureCodesScript.EVIDENCE_INVALID,
		path,
		"Independent observer A/B semantic recomputation [%s]: %s" % [
			semantic_code,
			message,
		])


static func _validate_current_l0_artifact_contract(
		manifest: Dictionary,
		declared_required: Array[String],
		errors: Array) -> void:
	var experiment_id := String(manifest.get("experiment_id", ""))
	if not CURRENT_L0_EXPERIMENTS.has(experiment_id):
		return
	var required := CURRENT_L0_REQUIRED_ARTIFACTS.duplicate()
	if experiment_id == "L0_3_OBSERVER_AB":
		required.append_array(L0_OBSERVER_AB_REQUIRED_ARTIFACTS)
	var process_isolation := String(manifest.get("process_isolation", ""))
	var execution_mode := String(manifest.get("execution_mode", ""))
	if not process_isolation in [
		DIRECT_PROCESS_ISOLATION,
		OUTER_PROCESS_ISOLATION,
	]:
		_add(
			errors,
			FailureCodesScript.EVIDENCE_INVALID,
			"/manifest.json/process_isolation",
			"Current L0 evidence must declare one supported process-isolation contract.")
	var launch_plan_required := (
		process_isolation == OUTER_PROCESS_ISOLATION
		or execution_mode == "promotion")
	if launch_plan_required:
		required.append("launch_plan.json")
	if execution_mode == "promotion" \
			and process_isolation != OUTER_PROCESS_ISOLATION:
		_add(
			errors,
			FailureCodesScript.EVIDENCE_INVALID,
			"/manifest.json/process_isolation",
			"Promotion evidence must use the reserved outer-parent/fresh-child process contract.")
	for artifact_name in required:
		if artifact_name in declared_required:
			continue
		_add(
			errors,
			FailureCodesScript.ARTIFACT_MISSING,
			"/manifest.json/required_artifacts",
			"Current %s evidence must declare LabRunner artifact: %s" % [
				experiment_id,
				artifact_name,
			])


static func _validate_expanded_experiment_integrity(
		manifest: Dictionary,
		errors: Array) -> void:
	var experiment_id := String(manifest.get("experiment_id", ""))
	if not CURRENT_L0_EXPERIMENTS.has(experiment_id):
		return
	var expanded_value: Variant = manifest.get("expanded_parameters")
	if typeof(expanded_value) != TYPE_DICTIONARY:
		_add(
			errors,
			FailureCodesScript.EVIDENCE_INVALID,
			"/manifest.json/expanded_parameters",
			"Current L0 manifest must seal its fully expanded experiment.")
		return
	var expanded: Dictionary = expanded_value
	var observer_value: Variant = expanded.get("observer_profile")
	var observer_profile_id := String(expanded.get(
		"observer_profile_id", ""))
	var registered_observer_match := false
	if (
		typeof(observer_value) == TYPE_DICTIONARY
		and ObserverProfileScript.has_profile(
			StringName(observer_profile_id))
	):
		registered_observer_match = (
			CanonicalJsonScript.sha256(observer_value)
			== CanonicalJsonScript.sha256(
				ObserverProfileScript.resolve(
					StringName(observer_profile_id))))
	var expanded_fixture: Dictionary = expanded.get(
		"fixture_parameters", {})
	var consistent := (
		String(manifest.get("expanded_spec_sha256", ""))
			== CanonicalJsonScript.sha256(expanded)
		and String(expanded.get("experiment_id", "")) == experiment_id
		and String(expanded.get("hypothesis_id", ""))
			== String(manifest.get("hypothesis_id", ""))
		and String(expanded.get("fixture_id", ""))
			== String(manifest.get("fixture_id", ""))
		and int(expanded.get("fixture_version", -1))
			== int(manifest.get("fixture_version", -2))
		and int(expanded.get("root_seed", 0))
			== int(manifest.get("seed_root", 1))
		and int(expanded.get("physics_ticks_per_second", -1))
			== int(manifest.get("physics_ticks_per_second", -2))
		and observer_profile_id
			== String(manifest.get("observer_profile", ""))
		and registered_observer_match
		and CanonicalJsonScript.sha256(
			expanded.get("body_parameters", {}))
			== CanonicalJsonScript.sha256(
				manifest.get("body_dynamics", {}))
		and int(expanded_fixture.get("contact_cap", -1))
			== int(manifest.get("contact_cap_per_body", -2)))
	if consistent:
		return
	_add(
		errors,
		FailureCodesScript.EVIDENCE_INVALID,
		"/manifest.json/expanded_parameters",
		(
			"Expanded-spec hash, registered observer, fixture, seed, timing, "
			+ "dynamics, and manifest identity do not agree."))


static func _validate_configuration_integrity(
		directory: String,
		manifest: Dictionary,
		summary: Dictionary,
		errors: Array) -> void:
	var path := directory.path_join("configuration.json")
	if not FileAccess.file_exists(path):
		return
	var read := _read_and_validate(
		path, SCHEMA_BY_ARTIFACT["configuration.json"])
	if not read["ok"]:
		return
	var evidence: Dictionary = read["value"]
	var resolved_sha := CanonicalJsonScript.sha256(evidence["resolved"])
	var applied_sha := CanonicalJsonScript.sha256(evidence["applied"])
	var observed_sha := CanonicalJsonScript.sha256(evidence["observed"])
	var hash_match := resolved_sha == applied_sha
	var resolved: Dictionary = evidence["resolved"]
	var applied: Dictionary = evidence["applied"]
	var observed: Dictionary = evidence["observed"]
	var observer: Dictionary = applied["observer_identity"]
	var actual_fixture: Dictionary = observed.get(
		"actual_fixture_parameters", {})
	var availability: Dictionary = observed.get(
		"observer_channel_availability", {})
	var channel_ids: Array = availability.keys()
	channel_ids.sort()
	var availability_entries_coherent := not channel_ids.is_empty()
	var derived_available_count := 0
	for channel_id_value in channel_ids:
		var availability_entry: Dictionary = availability[channel_id_value]
		var status := String(availability_entry.get("status", ""))
		var reason: Variant = availability_entry.get("reason")
		var source: Variant = availability_entry.get("source")
		if status in ["measured", "derived"]:
			derived_available_count += 1
			availability_entries_coherent = (
				availability_entries_coherent
				and reason == null
				and source is String
				and not String(source).is_empty())
		elif status == "unavailable":
			availability_entries_coherent = (
				availability_entries_coherent
				and reason is String
				and not String(reason).is_empty()
				and source == null)
		else:
			availability_entries_coherent = false
	var profile_channel_count := int(observer["channel_count"])
	var availability_complete := (
		profile_channel_count > 0
		and channel_ids.size() == profile_channel_count)
	var derived_observer_contract := (
		availability_entries_coherent
		and availability_complete
		and derived_available_count == profile_channel_count)
	var channel_identity := {
		"profile_id": String(observer["profile_id"]),
		"channels": channel_ids,
		"contacts_enabled": bool(observer["contacts_enabled"]),
		"contact_cap_per_body": int(observer["contact_cap_per_body"]),
	}
	var registered_observer_match := false
	var observer_profile_id := String(observer["profile_id"])
	if ObserverProfileScript.has_profile(
			StringName(observer_profile_id)):
		var registered_profile: Dictionary = ObserverProfileScript.resolve(
			StringName(observer_profile_id))
		registered_observer_match = (
			String(registered_profile["channel_set_sha256"])
				== String(observer["channel_set_sha256"])
			and (registered_profile["channels"] as Array).size()
				== profile_channel_count
			and bool(registered_profile["contacts_enabled"])
				== bool(observer["contacts_enabled"])
			and int(registered_profile["contact_cap_per_body"])
				== int(observer["contact_cap_per_body"]))
	var observer_evidence_coherent := (
		registered_observer_match
		and String(observer["channel_set_sha256"])
			== CanonicalJsonScript.sha256(channel_identity)
		and int(observed.get(
			"observer_profile_channel_count", -1))
			== profile_channel_count
		and int(observed.get(
			"observer_projected_channel_count", -1)) >= 0
		and int(observed.get(
			"observer_projected_channel_count", -1))
			<= profile_channel_count
		and int(observed.get(
			"observer_available_channel_count", -1))
			== derived_available_count
		and bool(observed.get(
			"observer_contract_satisfied", false))
			== derived_observer_contract)
	var expanded: Dictionary = manifest.get("expanded_parameters", {})
	var expanded_fixture: Dictionary = expanded.get(
		"fixture_parameters", {})
	var manifest_configuration_match := (
		String(manifest.get("observer_profile", ""))
			== String(observer["profile_id"])
		and String(manifest.get("observer_channel_set_sha256", ""))
			== String(observer["channel_set_sha256"])
		and int(manifest.get("contact_cap_per_body", -1))
			== int(observer["contact_cap_per_body"])
		and String(manifest.get("physics_backend_adapter", ""))
			== String(observed.get("observer_adapter_id", ""))
		and CanonicalJsonScript.sha256(
			manifest.get("body_dynamics", {}))
			== CanonicalJsonScript.sha256(
				resolved["body_parameters"])
		and CanonicalJsonScript.sha256(
			expanded.get("body_parameters", {}))
			== CanonicalJsonScript.sha256(
				resolved["body_parameters"])
		and int(expanded_fixture.get("contact_cap", -1))
			== int(resolved["fixture_contact_cap"])
		and String(expanded.get("observer_profile_id", ""))
			== String(observer["profile_id"]))
	var applied_observed_match := (
		CanonicalJsonScript.sha256(applied["body_parameters"])
			== CanonicalJsonScript.sha256(
				observed.get("actual_body_parameters", {}))
		and int(applied["fixture_contact_cap"])
			== int(actual_fixture.get("contact_cap", -1))
		and String(observer["profile_id"])
			== String(observed.get("observer_profile_id", ""))
		and int(observer["channel_count"])
			== int(observed.get(
				"observer_profile_channel_count", -1))
		and bool(observer["contacts_enabled"])
			== bool(observed.get(
				"observer_contacts_enabled", false))
		and bool(observer["contacts_enabled"])
			== bool(actual_fixture.get("contacts_enabled", false))
		and int(observer["contact_cap_per_body"])
			== int(observed.get(
				"observer_contact_cap_per_body", -1))
		and int(observer["contact_cap_per_body"])
			== int(actual_fixture.get(
				"effective_contact_cap_per_body", -1))
		and observer_evidence_coherent
		and manifest_configuration_match)
	var observer_arms_valid := true
	if String(manifest.get("experiment_id", "")) \
			== "L0_3_OBSERVER_AB":
		observer_arms_valid = _validate_l03_configuration_arms(
			evidence, manifest, errors)
	var derived_valid := (
		hash_match
		and applied_observed_match
		and (evidence.get("errors", []) as Array).is_empty()
		and derived_observer_contract
		and observer_arms_valid)
	var summary_gate: Dictionary = summary.get(
		"gate_results", {}).get("configuration", {})
	var consistent: bool = (
		String(evidence["run_id"]) == String(manifest["run_id"])
		and String(evidence["resolved_configuration_sha256"])
			== resolved_sha
		and String(evidence["applied_configuration_sha256"])
			== applied_sha
		and String(evidence["observed_configuration_sha256"])
			== observed_sha
		and bool(evidence["match"]) == hash_match
		and bool(evidence["configuration_valid"]) == derived_valid
		and String(manifest.get(
			"resolved_configuration_sha256", "")) == resolved_sha
		and String(manifest.get(
			"applied_configuration_sha256", "")) == applied_sha
		and String(summary_gate.get(
			"resolved_configuration_sha256", "")) == resolved_sha
		and String(summary_gate.get(
			"applied_configuration_sha256", "")) == applied_sha
		and bool(summary_gate.get("pass", false)) == derived_valid
		and String(summary_gate.get("gate_id", ""))
			== "G0_CONFIGURATION_INTEGRITY"
		and summary_gate.has("errors")
		and CanonicalJsonScript.sha256(
			summary_gate.get("errors", []))
			== CanonicalJsonScript.sha256(
				evidence.get("errors", []))
		and String(summary_gate.get("source_artifact", ""))
			== "configuration.json")
	if not consistent:
		_add(
			errors,
			FailureCodesScript.EVIDENCE_INVALID,
			"/configuration.json",
			(
				"Configuration hashes, preimages, live observations, "
				+ "manifest, and summary gate do not independently agree."))


static func _validate_l03_configuration_arms(
		evidence: Dictionary,
		manifest: Dictionary,
		errors: Array) -> bool:
	var arms_value: Variant = evidence.get("observer_arms")
	if typeof(arms_value) != TYPE_DICTIONARY:
		_add(
			errors,
			FailureCodesScript.EVIDENCE_INVALID,
			"/configuration.json/observer_arms",
			"L0.3 must preserve resolved, applied, and observed configuration for all three observer arms.")
		return false
	var arms: Dictionary = arms_value
	var expected_profiles := {
		"minimal": "minimal_state_v1",
		"full": "full_state_v1",
		"contact": "full_contacts_v1",
	}
	# ObservedRigidBody projects only callback-local channels. Whole-body
	# momentum and contact-impulse availability are completed by the sealed
	# frame builder, so projected count is intentionally lower than the final
	# available-channel count for the richer profiles.
	var expected_local_projection_counts := {
		"minimal": 5,
		"full": 7,
		"contact": 8,
	}
	var actual_arm_ids: Array = arms.keys()
	actual_arm_ids.sort()
	var expected_arm_ids: Array = expected_profiles.keys()
	expected_arm_ids.sort()
	if actual_arm_ids != expected_arm_ids:
		_add(
			errors,
			FailureCodesScript.EVIDENCE_INVALID,
			"/configuration.json/observer_arms",
			"L0.3 configuration evidence must contain exactly minimal, full, and contact arms.")
		return false
	var expanded: Dictionary = manifest.get("expanded_parameters", {})
	var body_parameters: Dictionary = expanded.get(
		"body_parameters", {})
	var fixture_parameters: Dictionary = expanded.get(
		"fixture_parameters", {})
	var expected_fixture_cap := int(fixture_parameters.get(
		"contact_cap", -1))
	var all_valid := true
	for arm_name_value in expected_arm_ids:
		var arm_name := String(arm_name_value)
		var arm: Dictionary = arms[arm_name_value]
		var profile_id := String(expected_profiles[arm_name_value])
		var profile: Dictionary = ObserverProfileScript.resolve(
			StringName(profile_id))
		var expected_observer := {
			"profile_id": profile_id,
			"channel_set_sha256": profile["channel_set_sha256"],
			"channel_count": (profile["channels"] as Array).size(),
			"contacts_enabled": bool(profile["contacts_enabled"]),
			"contact_cap_per_body":
				int(profile["contact_cap_per_body"]),
		}
		var expected_resolved := {
			"body_parameters": body_parameters.duplicate(true),
			"fixture_contact_cap": expected_fixture_cap,
			"observer_identity": expected_observer,
		}
		var resolved: Dictionary = arm.get("resolved", {})
		var applied: Dictionary = arm.get("applied", {})
		var observed: Dictionary = arm.get("observed", {})
		var resolved_sha := CanonicalJsonScript.sha256(resolved)
		var applied_sha := CanonicalJsonScript.sha256(applied)
		var observed_sha := CanonicalJsonScript.sha256(observed)
		var actual_fixture: Dictionary = observed.get(
			"actual_fixture_parameters", {})
		var channel_availability: Dictionary = observed.get(
			"observer_channel_availability", {})
		var expected_channels: Array = (
			profile["channels"] as Array).duplicate()
		expected_channels.sort()
		var actual_channels: Array = channel_availability.keys()
		actual_channels.sort()
		var availability_valid := actual_channels == expected_channels
		for channel_id_value in actual_channels:
			var channel: Dictionary = channel_availability[
				channel_id_value]
			availability_valid = (
				availability_valid
				and String(channel.get("status", ""))
					in ["measured", "derived"]
				and channel.get("reason") == null
				and channel.get("source") is String
				and not String(channel.get("source", "")).is_empty())
		var arm_valid := (
			CanonicalJsonScript.sha256(resolved)
				== CanonicalJsonScript.sha256(expected_resolved)
			and CanonicalJsonScript.sha256(applied)
				== CanonicalJsonScript.sha256(expected_resolved)
			and String(arm.get(
				"resolved_configuration_sha256", "")) == resolved_sha
			and String(arm.get(
				"applied_configuration_sha256", "")) == applied_sha
			and String(arm.get(
				"observed_configuration_sha256", "")) == observed_sha
			and bool(arm.get("match", false))
				== (resolved_sha == applied_sha)
			and bool(arm.get("configuration_valid", false))
			and (arm.get("errors", []) as Array).is_empty()
			and CanonicalJsonScript.sha256(
				observed.get("actual_body_parameters", {}))
				== CanonicalJsonScript.sha256(body_parameters)
			and int(actual_fixture.get("contact_cap", -1))
				== expected_fixture_cap
			and bool(actual_fixture.get("contacts_enabled", false))
				== bool(profile["contacts_enabled"])
			and int(actual_fixture.get(
				"effective_contact_cap_per_body", -1))
				== int(profile["contact_cap_per_body"])
			and String(observed.get("observer_profile_id", ""))
				== profile_id
			and String(observed.get("observer_adapter_id", ""))
				== String(manifest.get(
					"physics_backend_adapter", ""))
			and int(observed.get(
				"observer_profile_channel_count", -1))
				== expected_channels.size()
			and int(observed.get(
				"observer_projected_channel_count", -1))
				== int(expected_local_projection_counts[arm_name_value])
			and int(observed.get(
				"observer_available_channel_count", -1))
				== expected_channels.size()
			and bool(observed.get(
				"observer_contract_satisfied", false))
			and bool(observed.get(
				"observer_contacts_enabled", false))
				== bool(profile["contacts_enabled"])
			and int(observed.get(
				"observer_contact_cap_per_body", -1))
				== int(profile["contact_cap_per_body"])
			and availability_valid)
		if not arm_valid:
			all_valid = false
			_add(
				errors,
				FailureCodesScript.EVIDENCE_INVALID,
				"/configuration.json/observer_arms/%s" % arm_name,
				(
					"L0.3 observer arm does not reproduce its registered "
					+ "profile, resolved settings, live application, hashes, "
					+ "or channel availability."))
	return all_valid


static func _validate_launch_provenance(
		directory: String,
		manifest: Dictionary,
		summary: Dictionary,
		artifacts: Dictionary,
		errors: Array) -> void:
	var run_id := String(manifest.get("run_id", ""))
	var plan_path := directory.path_join("launch_plan.json")
	var metadata_path := directory.path_join("process_metadata.json")
	var has_plan := FileAccess.file_exists(plan_path)
	var has_metadata := FileAccess.file_exists(metadata_path)
	if not has_metadata:
		if has_plan:
			_add(
				errors,
				FailureCodesScript.EVIDENCE_INVALID,
				"/launch_plan.json",
				"Launch plan and terminal process metadata must be sealed together.")
		return
	var metadata_read := _read_and_validate(
		metadata_path, SCHEMA_BY_ARTIFACT["process_metadata.json"])
	if not metadata_read["ok"]:
		return
	var metadata: Dictionary = metadata_read["value"]
	if not has_plan:
		if CURRENT_L0_EXPERIMENTS.has(
				String(manifest.get("experiment_id", ""))):
			_validate_direct_process_metadata(
				manifest, summary, metadata, errors)
		return
	var plan_read := _read_and_validate(
		plan_path, SCHEMA_BY_ARTIFACT["launch_plan.json"])
	if not plan_read["ok"]:
		return
	var plan: Dictionary = plan_read["value"]
	var payload: Dictionary = plan["payload"]
	var experiment_identity: Dictionary = payload["experiment_identity"]
	var expected_arguments: Array = payload["engine_arguments"].duplicate()
	expected_arguments.append("--")
	expected_arguments.append_array(payload["user_arguments"])
	var checksummed_plan_sha := ""
	if artifacts.has("launch_plan.json"):
		checksummed_plan_sha = String(
			artifacts["launch_plan.json"].get("sha256", ""))
	var consistent: bool = (
		String(plan["run_id"]) == run_id
		and String(payload["run_id"]) == run_id
		and String(metadata["run_id"]) == run_id
		and (
			not CURRENT_L0_EXPERIMENTS.has(
				String(manifest.get("experiment_id", "")))
			or String(manifest.get("process_isolation", ""))
				== OUTER_PROCESS_ISOLATION)
		and String(plan["reservation_id"])
			== String(payload["reservation_id"])
		and String(metadata.get("reservation_id", ""))
			== String(plan["reservation_id"])
		and CanonicalJsonScript.sha256(payload)
			== String(plan["payload_sha256"])
		and metadata["arguments"] == expected_arguments
		and payload["arguments"] == expected_arguments
		and metadata["engine_arguments"]
			== payload["engine_arguments"]
		and metadata["user_arguments"] == payload["user_arguments"]
		and metadata["requested_user_arguments"]
			== payload["requested_user_arguments"]
		and String(metadata["executable"])
			== String(payload["executable"])
		and String(metadata["working_directory"])
			== String(payload["working_directory"])
		and metadata["log_paths"] == payload["log_paths"]
		and int(metadata["parent_process_id"])
			== int(payload["parent_process_id"])
		and int(metadata["termination_observer_process_id"])
			== int(payload["parent_process_id"])
		and int(metadata["child_process_id"]) > 0
		and int(metadata["child_process_id"])
			!= int(metadata["parent_process_id"])
		and String(metadata["status"]) == "COMPLETE"
		and int(metadata["exit_code"]) == 0
		and String(metadata["argument_capture_quality"])
			== "launcher_exact"
		and String(metadata.get("launch_plan_path", ""))
			== String(payload["partial_path"]).path_join(
				"launch_plan.json")
		and String(metadata.get("launch_plan_sha256", ""))
			== checksummed_plan_sha
		and String(metadata.get(
			"launch_plan_payload_sha256", ""))
			== String(plan["payload_sha256"])
		and String(metadata.get(
			"adoption_token_sha256", ""))
			== String(payload["adoption_token_sha256"])
		and String(metadata.get("partial_path", ""))
			== String(payload["partial_path"])
		and String(metadata.get("final_path", ""))
			== String(payload["final_path"])
		and String(metadata["started_utc"])
			== String(payload["created_utc"])
		and String(experiment_identity.get("resource_path", ""))
			== String(manifest.get("experiment_resource_path", ""))
		and String(experiment_identity.get("resource_sha256", ""))
			== String(manifest.get("experiment_resource_sha256", ""))
		and String(experiment_identity.get("expanded_spec_sha256", ""))
			== String(manifest.get("expanded_spec_sha256", ""))
		and String(experiment_identity.get("experiment_id", ""))
			== String(manifest.get("experiment_id", ""))
		and int(experiment_identity.get("root_seed", 0))
			== int(manifest.get("seed_root", 1))
		and String(experiment_identity.get("observer_profile_id", ""))
			== String(manifest.get("observer_profile", "")))
	if not consistent:
		_add(
			errors,
			FailureCodesScript.EVIDENCE_INVALID,
			"/launch_plan.json",
			"Frozen launch plan, exact argv, terminal process metadata, and sealed plan hash do not agree.")


static func _validate_direct_process_metadata(
		manifest: Dictionary,
		summary: Dictionary,
		metadata: Dictionary,
		errors: Array) -> void:
	var expected_exit_code := (
		0 if String(summary.get("promotion", "")) == "pass" else 2)
	var expected_disposition := (
		"promotion_pass"
		if expected_exit_code == 0
		else "completed_development")
	var child_process_id := int(metadata.get("child_process_id", -1))
	var direct_metadata_valid := (
		String(manifest.get("process_isolation", ""))
			== DIRECT_PROCESS_ISOLATION
		and String(metadata.get("run_id", ""))
			== String(manifest.get("run_id", ""))
		and String(metadata.get("status", "")) == "COMPLETE"
		and int(metadata.get("parent_process_id", -2)) == -1
		and child_process_id > 0
		and int(metadata.get(
			"termination_observer_process_id", -1))
			== child_process_id
		and String(metadata.get("argument_capture_quality", ""))
			== "godot_runtime_observed"
		and int(metadata.get("exit_code", -1)) == expected_exit_code
		and String(metadata.get("exit_disposition", ""))
			== expected_disposition
		and metadata.get("reservation_id") == null
		and metadata.get("launch_plan_path") == null
		and metadata.get("launch_plan_sha256") == null
		and metadata.get("launch_plan_payload_sha256") == null
		and metadata.get("adoption_token_sha256") == null
		and metadata.get("partial_path") == null
		and metadata.get("final_path") == null)
	if direct_metadata_valid:
		return
	_add(
		errors,
		FailureCodesScript.EVIDENCE_INVALID,
		"/process_metadata.json",
		"Direct L0 process metadata does not match its terminal in-process development contract.")


static func _validate_source_state_summary(
		manifest: Dictionary,
		summary: Dictionary,
		errors: Array) -> void:
	if not CURRENT_L0_EXPERIMENTS.has(
			String(manifest.get("experiment_id", ""))):
		return
	var gate_results_value: Variant = summary.get("gate_results")
	if typeof(gate_results_value) != TYPE_DICTIONARY:
		_add(
			errors,
			FailureCodesScript.EVIDENCE_INVALID,
			"/summary.json/gate_results",
			"Current L0 evidence must seal its source-state gate.")
		return
	var recorded_value: Variant = (gate_results_value as Dictionary).get(
		"source_state")
	if typeof(recorded_value) != TYPE_DICTIONARY:
		_add(
			errors,
			FailureCodesScript.EVIDENCE_INVALID,
			"/summary.json/gate_results/source_state",
			"Current L0 evidence must seal its source-state gate.")
		return
	var loaded_hashes_value: Variant = manifest.get(
		"loaded_resource_hashes")
	var loaded_hashes: Dictionary = (
		(loaded_hashes_value as Dictionary)
		if typeof(loaded_hashes_value) == TYPE_DICTIONARY
		else {})
	var expected: Dictionary = SourceStateGateScript.assess(
		String(manifest.get("git_commit", "")),
		bool(manifest.get("dirty_worktree", true)),
		loaded_hashes)
	if String(manifest.get("process_isolation", "")) \
			== DIRECT_PROCESS_ISOLATION:
		expected = expected.duplicate(true)
		expected["pass"] = false
		expected["execution_mode"] = "development"
		expected["reproducibility"] = (
			"direct_in_process_development_only")
		var direct_reasons: Array = expected.get("reasons", []).duplicate()
		direct_reasons.append("NON_CANONICAL_DIRECT_RUN")
		direct_reasons.sort()
		expected["reasons"] = direct_reasons
	var expected_manifest_reproducibility := (
		"clean_committed_source"
		if bool(expected["pass"])
		else "partial_dirty_source")
	var consistent := (
		CanonicalJsonScript.sha256(recorded_value)
			== CanonicalJsonScript.sha256(expected)
		and String(manifest.get("execution_mode", ""))
			== String(expected["execution_mode"])
		and String(manifest.get("reproducibility", ""))
			== expected_manifest_reproducibility)
	if consistent:
		return
	_add(
		errors,
		FailureCodesScript.EVIDENCE_INVALID,
		"/summary.json/gate_results/source_state",
		(
			"Recorded source-state gate and manifest labels do not reproduce "
			+ "from the sealed commit, dirty flag, resource hashes, and "
			+ "process-isolation contract."))


static func _validate_live_source_state(manifest: Dictionary, blockers: Array) -> void:
	if bool(manifest.get("dirty_worktree", true)):
		return
	if String(manifest.get("reproducibility", "")) != "clean_committed_source":
		_add(
			blockers,
			FailureCodesScript.DIRTY_SOURCE_NOT_PROMOTABLE,
			"/manifest.json/reproducibility",
			"Promotion source must be labeled clean_committed_source.")
	var loaded_hashes_value: Variant = manifest.get("loaded_resource_hashes")
	if typeof(loaded_hashes_value) != TYPE_DICTIONARY \
			or (loaded_hashes_value as Dictionary).is_empty():
		_add(
			blockers,
			FailureCodesScript.DIRTY_SOURCE_NOT_PROMOTABLE,
			"/manifest.json/loaded_resource_hashes",
			"Promotion requires the complete loaded resource hash map.")
		return
	var loaded_hashes: Dictionary = loaded_hashes_value
	for pair in [
		[
			String(manifest.get("experiment_resource_path", "")),
			String(manifest.get("experiment_resource_sha256", "")),
		],
		[
			String(manifest.get("fixture_resource_path", "")),
			String(manifest.get("fixture_resource_sha256", "")),
		],
	]:
		var resource_path := String(pair[0])
		var resource_hash := String(pair[1])
		if resource_path.is_empty() \
				or not loaded_hashes.has(resource_path) \
				or String(loaded_hashes[resource_path]) != resource_hash:
			_add(
				blockers,
				FailureCodesScript.DIRTY_SOURCE_NOT_PROMOTABLE,
				"/manifest.json/loaded_resource_hashes",
				"Experiment and fixture identities must be present in the loaded hash map.")

	var assessed := SourceStateGateScript.assess(
		String(manifest.get("git_commit", "")),
		bool(manifest.get("dirty_worktree", true)),
		loaded_hashes)
	if not assessed["pass"]:
		_add(
			blockers,
			FailureCodesScript.DIRTY_SOURCE_NOT_PROMOTABLE,
			"/manifest.json/git_commit",
			"Recorded source-state gate failed: %s" % JSON.stringify(assessed["reasons"]))
		return

	var repository_path := ProjectSettings.globalize_path("res://")
	var live_probe := SourceStateGateScript.probe_repository(repository_path)
	if not live_probe["ok"] \
			or bool(live_probe["dirty_worktree"]) \
			or String(live_probe["git_commit"]).to_lower() \
				!= String(manifest.get("git_commit", "")).to_lower():
		_add(
			blockers,
			FailureCodesScript.DIRTY_SOURCE_NOT_PROMOTABLE,
			"/manifest.json/git_commit",
			"Live clean HEAD does not match the source revision sealed by the run.")
		return

	var paths := loaded_hashes.keys()
	paths.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for path_value in paths:
		var path := String(path_value)
		if not path.begins_with("res://") or not FileAccess.file_exists(path):
			_add(
				blockers,
				FailureCodesScript.DIRTY_SOURCE_NOT_PROMOTABLE,
				"/manifest.json/loaded_resource_hashes/%s" % path,
				"Loaded promotion resource is absent or outside res://.")
			continue
		var live_hash := "sha256:%s" % FileAccess.get_sha256(path)
		if live_hash != String(loaded_hashes[path_value]):
			_add(
				blockers,
				FailureCodesScript.DIRTY_SOURCE_NOT_PROMOTABLE,
				"/manifest.json/loaded_resource_hashes/%s" % path,
				"Loaded resource bytes do not match the sealed hash.")
	var experiment_path := String(manifest.get(
		"experiment_resource_path", ""))
	var experiment_sha := String(manifest.get(
		"experiment_resource_sha256", ""))
	var loaded = ResourceLoader.load(
		experiment_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or not loaded.has_method(
			"to_value_dictionary"):
		_add(
			blockers,
			FailureCodesScript.DIRTY_SOURCE_NOT_PROMOTABLE,
			"/manifest.json/experiment_resource_path",
			"Promotion cannot reload the sealed ExperimentSpec from the verified source tree.")
		return
	var compiled: Dictionary = SpecCompilerScript.compile(
		loaded,
		{},
		{
			"root_seed": int(manifest.get("seed_root", 0)),
			"observer_profile_id": String(manifest.get(
				"observer_profile", "")),
		},
		{
			"resource_path": experiment_path,
			"resource_sha256": experiment_sha,
		})
	if not bool(compiled.get("ok", false)):
		_add(
			blockers,
			FailureCodesScript.DIRTY_SOURCE_NOT_PROMOTABLE,
			"/manifest.json/expanded_spec_sha256",
			(
				"Promotion cannot recompile the authored ExperimentSpec "
				+ "under its sealed seed and observer overrides."))
		return
	var recompiled_experiment: RefCounted = compiled["experiment"]
	var recompiled_sha := String(
		recompiled_experiment.call("expanded_spec_sha256"))
	if (
		recompiled_sha
			!= String(manifest.get("expanded_spec_sha256", ""))
		or recompiled_sha
			!= CanonicalJsonScript.sha256(
				manifest.get("expanded_parameters", {}))
	):
		_add(
			blockers,
			FailureCodesScript.DIRTY_SOURCE_NOT_PROMOTABLE,
			"/manifest.json/expanded_spec_sha256",
			"Promotion expanded parameters do not reproduce from the clean authored ExperimentSpec.")


static func _read_and_validate(path: String, schema_path: String) -> Dictionary:
	var parsed := _read_json(path)
	if not parsed["ok"]:
		return parsed
	var validation := SchemaValidatorScript.validate_file(schema_path, parsed["value"])
	if not validation["ok"]:
		return {"ok": false, "errors": validation["errors"], "value": parsed["value"]}
	return {"ok": true, "errors": [], "value": parsed["value"]}


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"ok": false,
			"errors": [{
				"code": FailureCodesScript.ARTIFACT_MISSING,
				"path": "/",
				"message": "Artifact does not exist.",
			}],
			"value": null,
		}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"errors": [{
				"code": FailureCodesScript.ARTIFACT_MISSING,
				"path": "/",
				"message": "Artifact could not be opened.",
			}],
			"value": null,
		}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	if parse_error != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {
			"ok": false,
			"errors": [{
				"code": FailureCodesScript.JSON_PARSE_FAILED,
				"path": "/",
				"message": "JSON parse failed at line %d: %s" % [
					parser.get_error_line(),
					parser.get_error_message(),
				],
			}],
			"value": null,
		}
	return {"ok": true, "errors": [], "value": parser.data}


static func _validate_jsonl(path: String, artifact_name: String, run_id: String) -> Dictionary:
	var errors: Array = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_add(errors, FailureCodesScript.ARTIFACT_MISSING, "/", "JSONL stream could not be opened.")
		return {"ok": false, "errors": errors, "record_count": 0}
	var record_count := 0
	while file.get_position() < file.get_length():
		var line := file.get_line()
		if line.strip_edges().is_empty():
			_add(
				errors,
				FailureCodesScript.JSON_PARSE_FAILED,
				"/%d" % record_count,
				"Blank JSONL records are forbidden.")
			continue
		var parser := JSON.new()
		var parse_error := parser.parse(line)
		if parse_error != OK or typeof(parser.data) != TYPE_DICTIONARY:
			_add(
				errors,
				FailureCodesScript.JSON_PARSE_FAILED,
				"/%d" % record_count,
				"JSONL record is not a parseable object: %s" % parser.get_error_message())
			record_count += 1
			continue
		var record: Dictionary = parser.data
		var schema_path := String(SCHEMA_BY_ARTIFACT.get(artifact_name, ""))
		if schema_path.is_empty() or not FileAccess.file_exists(schema_path):
			_add(
				errors,
				FailureCodesScript.SCHEMA_INVALID,
				"/%d" % record_count,
				"No versioned schema is registered for this JSONL stream.")
		else:
			var validation := SchemaValidatorScript.validate_file(schema_path, record)
			if not validation["ok"]:
				for validation_error_value in validation["errors"]:
					var validation_error: Dictionary = validation_error_value.duplicate()
					validation_error["path"] = "/%d%s" % [
						record_count,
						validation_error.get("path", "/"),
					]
					errors.append(validation_error)
		var record_run_id := _record_run_id(record)
		if record_run_id.is_empty() or record_run_id != run_id:
			_add(
				errors,
				FailureCodesScript.RUN_ID_MISMATCH,
				"/%d/run_id" % record_count,
				"Record does not cross-link to the manifest run_id.")
		record_count += 1
	return {"ok": errors.is_empty(), "errors": errors, "record_count": record_count}


static func _record_run_id(record: Dictionary) -> String:
	if record.has("run_id"):
		return String(record["run_id"])
	if typeof(record.get("payload")) == TYPE_DICTIONARY and record["payload"].has("run_id"):
		return String(record["payload"]["run_id"])
	return ""


static func _validate_stream_counts(summary: Dictionary, counts: Dictionary, errors: Array) -> void:
	var frame_count := int(counts.get("frames.jsonl", 0))
	if int(summary["frame_count"]) != frame_count:
		_add(
			errors,
			FailureCodesScript.SUMMARY_COUNT_MISMATCH,
			"/summary.json/frame_count",
			"Summary frame_count does not equal frames.jsonl.")
	var note_count := int(counts.get("runtime_notes.jsonl", 0))
	if int(summary["runtime_note_count"]) != note_count:
		_add(
			errors,
			FailureCodesScript.SUMMARY_COUNT_MISMATCH,
			"/summary.json/runtime_note_count",
			"Summary runtime_note_count does not equal runtime_notes.jsonl.")


static func _validate_summary_frame_range(
		summary: Dictionary,
		frames_path: String,
		errors: Array) -> void:
	var frames := _optional_jsonl_values(frames_path)
	var expected_first: Variant = null
	var expected_last: Variant = null
	if not frames.is_empty():
		expected_first = int(frames[0].get("frame_id", -1))
		expected_last = int(frames[-1].get("frame_id", -1))
	if summary.get("first_frame_id") != expected_first:
		_add(
			errors,
			FailureCodesScript.SUMMARY_COUNT_MISMATCH,
			"/summary.json/first_frame_id",
			"Summary first_frame_id does not match frames.jsonl.")
	if summary.get("last_frame_id") != expected_last:
		_add(
			errors,
			FailureCodesScript.SUMMARY_COUNT_MISMATCH,
			"/summary.json/last_frame_id",
			"Summary last_frame_id does not match frames.jsonl.")


static func _validate_frame_order(path: String, errors: Array) -> void:
	if not FileAccess.file_exists(path):
		return
	var records := _read_jsonl_values(path)
	if not records["ok"]:
		return
	var previous_id := -1
	var previous_time := -1.0
	for index in records["values"].size():
		var frame: Dictionary = records["values"][index]
		var frame_id := int(frame.get("frame_id", -1))
		var physics_time := float(frame.get("physics_time_s", -1.0))
		if frame_id <= previous_id:
			_add(
				errors,
				FailureCodesScript.RECORD_ORDER_INVALID,
				"/frames.jsonl/%d/frame_id" % index,
				"frame_id must be strictly increasing.")
		if physics_time < previous_time:
			_add(
				errors,
				FailureCodesScript.RECORD_ORDER_INVALID,
				"/frames.jsonl/%d/physics_time_s" % index,
				"physics_time_s must be monotonic.")
		previous_id = frame_id
		previous_time = physics_time


static func _validate_note_order(path: String, errors: Array) -> void:
	if not FileAccess.file_exists(path):
		return
	var records := _read_jsonl_values(path)
	if not records["ok"]:
		return
	var previous_sequence := -1
	for index in records["values"].size():
		var note: Dictionary = records["values"][index]
		var sequence := int(note.get("note_sequence", -1))
		if sequence <= previous_sequence:
			_add(
				errors,
				FailureCodesScript.RECORD_ORDER_INVALID,
				"/runtime_notes.jsonl/%d/note_sequence" % index,
				"note_sequence must be strictly increasing.")
		previous_sequence = sequence


static func _validate_cross_record_links(directory: String, errors: Array) -> void:
	var frame_ids: Dictionary = {}
	var frame_sequence: Array[int] = []
	for frame_value in _optional_jsonl_values(directory.path_join("frames.jsonl")):
		var frame_id := int(frame_value.get("frame_id", -1))
		frame_ids[frame_id] = true
		frame_sequence.append(frame_id)
	var plans: Dictionary = {}
	var intervention_references: Array = []
	var commands_path := directory.path_join("commands.jsonl")
	var command_values := _optional_jsonl_values(commands_path)
	var command_sources: Dictionary = {}
	var previous_command_id := -1
	for command_index in command_values.size():
		var envelope: Dictionary = command_values[command_index]
		if typeof(envelope.get("payload")) != TYPE_DICTIONARY:
			continue
		var payload: Dictionary = envelope.get("payload", {})
		var sealed_hash := String(envelope.get("command_payload_sha256", ""))
		if CanonicalJsonScript.sha256(payload) != sealed_hash:
			_add(
				errors,
				FailureCodesScript.ENVELOPE_HASH_MISMATCH,
				"/commands.jsonl/%d/command_payload_sha256" % command_index,
				"Command payload bytes do not match the sealed envelope hash.")
		var command_id := int(payload.get("command_id", -1))
		var source_frame_id := int(payload.get("source_frame_id", -1))
		if command_id != source_frame_id:
			_add(
				errors,
				FailureCodesScript.TRANSITION_INVALID,
				"/commands.jsonl/%d/payload/command_id" % command_index,
				"BR1 command_id must equal its source_frame_id.")
		if command_id <= previous_command_id or command_sources.has(source_frame_id):
			_add(
				errors,
				FailureCodesScript.RECORD_ORDER_INVALID,
				"/commands.jsonl/%d/payload/command_id" % command_index,
				"Command IDs must be strictly increasing and source frames unique.")
		previous_command_id = command_id
		command_sources[source_frame_id] = true
		if not _is_transition(payload.get("applied_transition"), source_frame_id):
			_add(
				errors,
				FailureCodesScript.TRANSITION_INVALID,
				"/commands.jsonl/%d/payload/applied_transition" % command_index,
				"Command N must explicitly map frame N to N+1.")
		_require_frame_reference(
			frame_ids,
			source_frame_id,
			"/commands.jsonl/%d/payload/source_frame_id" % command_index,
			errors)
		_require_frame_reference(
			frame_ids,
			source_frame_id + 1,
			"/commands.jsonl/%d/payload/applied_transition/1" % command_index,
			errors)
		for joint_command_value in payload.get("joint_commands", []):
			if typeof(joint_command_value) != TYPE_DICTIONARY:
				continue
			var joint_command: Dictionary = joint_command_value
			for operation_value in joint_command.get("planned_application_operations", []):
				if typeof(operation_value) != TYPE_DICTIONARY:
					continue
				var operation: Dictionary = operation_value
				var operation_id := String(operation.get("operation_id", ""))
				var operation_path := "/commands.jsonl/%d/payload/joint_commands" % command_index
				_register_plan(plans, operation_id, {
					"source_kind": "command",
					"source_record_id": "command:%d" % command_id,
					"source_payload_sha256": sealed_hash,
					"api": String(operation.get("api", "RigidBody3D.apply_torque")),
					"target_body_id": String(operation.get("body_id", "")),
					"receipt_count": 0,
					"path": operation_path,
				}, operation_path, errors)
		for operation_id_value in payload.get("intervention_operation_ids", []):
			intervention_references.append({
				"operation_id": String(operation_id_value),
				"path": "/commands.jsonl/%d/payload/intervention_operation_ids" % command_index,
			})
	if FileAccess.file_exists(commands_path):
		for frame_index in range(maxi(frame_sequence.size() - 1, 0)):
			var source_id := frame_sequence[frame_index]
			if not command_sources.has(source_id):
				_add(
					errors,
					FailureCodesScript.RECORD_REFERENCE_MISSING,
					"/commands.jsonl",
					"No command record seals transition %d -> %d." % [
						source_id,
						frame_sequence[frame_index + 1],
					])
		if command_values.size() != maxi(frame_sequence.size() - 1, 0):
			_add(
				errors,
				FailureCodesScript.LINE_COUNT_MISMATCH,
				"/commands.jsonl",
				"BR1 requires exactly one command record per frame transition.")

	var intervention_values := _optional_jsonl_values(
		directory.path_join("interventions.jsonl"))
	for intervention_index in intervention_values.size():
		var envelope: Dictionary = intervention_values[intervention_index]
		if typeof(envelope.get("payload")) != TYPE_DICTIONARY:
			continue
		var payload: Dictionary = envelope.get("payload", {})
		var sealed_hash := String(envelope.get("intervention_payload_sha256", ""))
		if CanonicalJsonScript.sha256(payload) != sealed_hash:
			_add(
				errors,
				FailureCodesScript.ENVELOPE_HASH_MISMATCH,
				"/interventions.jsonl/%d/intervention_payload_sha256" % intervention_index,
				"Intervention payload bytes do not match the sealed envelope hash.")
		if String(payload.get("record_kind", "")) != "planned_operation":
			continue
		var source_frame_id := int(payload.get("source_frame_id", -1))
		if not _is_transition(payload.get("applied_transition"), source_frame_id):
			_add(
				errors,
				FailureCodesScript.TRANSITION_INVALID,
				"/interventions.jsonl/%d/payload/applied_transition" % intervention_index,
				"Planned intervention must name its source-to-result transition.")
		_require_frame_reference(
			frame_ids,
			source_frame_id,
			"/interventions.jsonl/%d/payload/source_frame_id" % intervention_index,
			errors)
		_require_frame_reference(
			frame_ids,
			source_frame_id + 1,
			"/interventions.jsonl/%d/payload/applied_transition/1" % intervention_index,
			errors)
		if not bool(payload.get("allowed", false)):
			continue
		var operation_id := String(payload.get("operation_id", ""))
		var operation_path := "/interventions.jsonl/%d/payload" % intervention_index
		_register_plan(plans, operation_id, {
			"source_kind": "intervention",
			"source_record_id": "intervention:%s" % operation_id,
			"source_payload_sha256": sealed_hash,
			"api": String(payload.get("planned_api", "")),
			"target_body_id": String(payload.get("target_body_id", "")),
			"receipt_count": 0,
			"path": operation_path,
		}, operation_path, errors)

	for reference_value in intervention_references:
		var reference: Dictionary = reference_value
		var operation_id := String(reference["operation_id"])
		if not plans.has(operation_id) \
				or String(plans[operation_id]["source_kind"]) != "intervention":
			_add(
				errors,
				FailureCodesScript.APPLICATION_LINK_MISMATCH,
				String(reference["path"]),
				"Command references an intervention plan that is absent or not allowed.")

	var application_values := _optional_jsonl_values(
		directory.path_join("applications.jsonl"))
	var previous_sequence := -1
	for application_index in application_values.size():
		var receipt: Dictionary = application_values[application_index]
		var sequence := int(receipt.get("application_sequence", -1))
		if sequence <= previous_sequence:
			_add(
				errors,
				FailureCodesScript.RECORD_ORDER_INVALID,
				"/applications.jsonl/%d/application_sequence" % application_index,
				"application_sequence must be strictly increasing.")
		previous_sequence = sequence
		var operation_id := String(receipt.get("operation_id", ""))
		if not plans.has(operation_id):
			_add(
				errors,
				FailureCodesScript.APPLICATION_LINK_MISMATCH,
				"/applications.jsonl/%d/operation_id" % application_index,
				"Application receipt does not reference a sealed allowed plan.")
			continue
		var plan: Dictionary = plans[operation_id]
		var matches := (
			String(receipt.get("source_kind", "")) == String(plan["source_kind"])
			and String(receipt.get("source_record_id", "")) == String(plan["source_record_id"])
			and String(receipt.get("source_payload_sha256", ""))
				== String(plan["source_payload_sha256"])
			and String(receipt.get("api", "")) == String(plan["api"])
			and String(receipt.get("target_body_id", "")) == String(plan["target_body_id"]))
		if not matches:
			_add(
				errors,
				FailureCodesScript.APPLICATION_LINK_MISMATCH,
				"/applications.jsonl/%d" % application_index,
				"Receipt source/hash/API/target does not match its sealed plan.")
		plan["receipt_count"] = int(plan["receipt_count"]) + 1
		plans[operation_id] = plan

	for operation_id_value in plans:
		var operation_id := String(operation_id_value)
		var plan: Dictionary = plans[operation_id_value]
		if int(plan["receipt_count"]) != 1:
			_add(
				errors,
				FailureCodesScript.APPLICATION_COUNT_MISMATCH,
				String(plan["path"]),
				"Planned operation %s has %d receipts; exactly one is required." % [
					operation_id,
					int(plan["receipt_count"]),
				])

	_validate_frame_linked_stream(
		directory.path_join("decisions.jsonl"),
		"source_frame_id",
		frame_ids,
		"decision_id",
		errors)
	_validate_frame_linked_stream(
		directory.path_join("events.jsonl"),
		"frame_id",
		frame_ids,
		"event_sequence",
		errors)
	_validate_frame_linked_stream(
		directory.path_join("runtime_notes.jsonl"),
		"frame_id",
		frame_ids,
		"note_sequence",
		errors,
		true)
	var mechanics_values := _optional_jsonl_values(
		directory.path_join("mechanics.jsonl"))
	var mechanics_sources: Dictionary = {}
	var previous_mechanics_source := -1
	for mechanics_index in mechanics_values.size():
		var mechanics: Dictionary = mechanics_values[mechanics_index]
		if typeof(mechanics.get("transition")) != TYPE_ARRAY:
			continue
		var transition: Array = mechanics.get("transition", [])
		if transition.size() == 2:
			var source_id := int(transition[0])
			var result_id := int(transition[1])
			if result_id != source_id + 1:
				_add(
					errors,
					FailureCodesScript.TRANSITION_INVALID,
					"/mechanics.jsonl/%d/transition" % mechanics_index,
					"BR1 mechanics records must describe adjacent N -> N+1 frames.")
			if source_id <= previous_mechanics_source or mechanics_sources.has(source_id):
				_add(
					errors,
					FailureCodesScript.RECORD_ORDER_INVALID,
					"/mechanics.jsonl/%d/transition" % mechanics_index,
					"Mechanics transitions must be strictly ordered and unique.")
			previous_mechanics_source = source_id
			mechanics_sources[source_id] = true
			_require_frame_reference(
				frame_ids,
				source_id,
				"/mechanics.jsonl/%d/transition/0" % mechanics_index,
				errors)
			_require_frame_reference(
				frame_ids,
				result_id,
				"/mechanics.jsonl/%d/transition/1" % mechanics_index,
				errors)
	var mechanics_path := directory.path_join("mechanics.jsonl")
	if FileAccess.file_exists(mechanics_path):
		for frame_index in range(maxi(frame_sequence.size() - 1, 0)):
			var source_id := frame_sequence[frame_index]
			if not mechanics_sources.has(source_id):
				_add(
					errors,
					FailureCodesScript.RECORD_REFERENCE_MISSING,
					"/mechanics.jsonl",
					"No mechanics record accounts for transition %d -> %d." % [
						source_id,
						frame_sequence[frame_index + 1],
					])
		if mechanics_values.size() != maxi(frame_sequence.size() - 1, 0):
			_add(
				errors,
				FailureCodesScript.LINE_COUNT_MISMATCH,
				"/mechanics.jsonl",
				"BR1 requires exactly one body mechanics record per frame transition.")


static func _register_plan(
		plans: Dictionary,
		operation_id: String,
		plan: Dictionary,
		path: String,
		errors: Array) -> void:
	if operation_id.is_empty() or plans.has(operation_id):
		_add(
			errors,
			FailureCodesScript.APPLICATION_LINK_MISMATCH,
			path,
			"Application operation IDs must be non-empty and globally unique within a run.")
		return
	plans[operation_id] = plan


static func _validate_frame_linked_stream(
		path: String,
		frame_field: String,
		frame_ids: Dictionary,
		sequence_field: String,
		errors: Array,
		allow_null_frame := false) -> void:
	var values := _optional_jsonl_values(path)
	var previous_sequence := -1
	for index in values.size():
		var record: Dictionary = values[index]
		var sequence := int(record.get(sequence_field, -1))
		if sequence <= previous_sequence:
			_add(
				errors,
				FailureCodesScript.RECORD_ORDER_INVALID,
				"/%s/%d/%s" % [path.get_file(), index, sequence_field],
				"%s must be strictly increasing." % sequence_field)
		previous_sequence = sequence
		if allow_null_frame and record.get(frame_field) == null:
			continue
		_require_frame_reference(
			frame_ids,
			int(record.get(frame_field, -1)),
			"/%s/%d/%s" % [path.get_file(), index, frame_field],
			errors)


static func _require_frame_reference(
		frame_ids: Dictionary,
		frame_id: int,
		path: String,
		errors: Array) -> void:
	if not frame_ids.has(frame_id):
		_add(
			errors,
			FailureCodesScript.RECORD_REFERENCE_MISSING,
			path,
			"Record references a frame_id that is absent from frames.jsonl.")


static func _is_transition(value: Variant, source_frame_id: int) -> bool:
	if typeof(value) != TYPE_ARRAY or value.size() != 2:
		return false
	return int(value[0]) == source_frame_id and int(value[1]) == source_frame_id + 1


static func _optional_jsonl_values(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var result := _read_jsonl_values(path)
	return result["values"] if result["ok"] else []


static func _validate_summary_provenance(
		summary: Dictionary,
		artifacts: Dictionary,
		directory: String,
		errors: Array) -> void:
	for index in summary.get("metrics", []).size():
		if typeof(summary["metrics"][index]) != TYPE_DICTIONARY:
			continue
		var metric: Dictionary = summary["metrics"][index]
		var has_unary := (
			metric.has("source_stream")
			or metric.has("source_frame_range")
			or metric.has("source_field"))
		var has_operands := metric.has("source_operands")
		if has_unary == has_operands:
			_add(
				errors,
				FailureCodesScript.EVIDENCE_INVALID,
				"/summary.json/metrics/%d" % index,
				"Metric must use exactly one unary or two-operand provenance form.")
			continue
		if has_unary:
			if (
				not metric.has("source_stream")
				or not metric.has("source_frame_range")
				or not metric.has("source_field")
			):
				_add(
					errors,
					FailureCodesScript.EVIDENCE_INVALID,
					"/summary.json/metrics/%d" % index,
					"Unary metric provenance is incomplete.")
				continue
			var source_stream := String(metric["source_stream"])
			if not artifacts.has(source_stream):
				_add(
					errors,
					FailureCodesScript.ARTIFACT_MISSING,
					"/summary.json/metrics/%d/source_stream" % index,
					"Metric provenance references an unsealed stream.")
			continue
		_validate_comparison_metric(
			summary,
			metric,
			index,
			artifacts,
			directory,
			errors)


static func _validate_comparison_metric(
		summary: Dictionary,
		metric: Dictionary,
		metric_index: int,
		artifacts: Dictionary,
		directory: String,
		errors: Array) -> void:
	var operands: Array = metric.get("source_operands", [])
	if operands.size() != 2:
		_add(
			errors,
			FailureCodesScript.EVIDENCE_INVALID,
			"/summary.json/metrics/%d/source_operands" % metric_index,
			"Comparison metric requires exactly two operands.")
		return
	if String(metric.get("aggregation_id", "")) \
			!= "max_pairwise_vec3_distance_v1" \
			or int(metric.get("aggregation_version", 0)) != 1:
		_add(
			errors,
			FailureCodesScript.EVIDENCE_INVALID,
			"/summary.json/metrics/%d/aggregation_id" % metric_index,
			"Comparison metric uses an unsupported reducer.")
		return
	var operand_frames: Array = []
	for operand_index in 2:
		var operand: Dictionary = operands[operand_index]
		var stream := String(operand.get("stream", ""))
		var operand_path := (
			"/summary.json/metrics/%d/source_operands/%d"
			% [metric_index, operand_index])
		if not artifacts.has(stream):
			_add(
				errors,
				FailureCodesScript.ARTIFACT_MISSING,
				"%s/stream" % operand_path,
				"Comparison operand references an unsealed stream.")
			return
		if String(operand.get("run_id", "")) \
				!= String(summary.get("run_id", "")):
			_add(
				errors,
				FailureCodesScript.RUN_ID_MISMATCH,
				"%s/run_id" % operand_path,
				"Comparison operand run_id does not match the bundle.")
			return
		var read_result := _read_jsonl_values(directory.path_join(stream))
		if not read_result["ok"]:
			_add(
				errors,
				FailureCodesScript.JSON_PARSE_FAILED,
				"%s/stream" % operand_path,
				"Comparison operand stream cannot be read.")
			return
		var frame_range: Array = operand.get("frame_range", [])
		if frame_range.size() != 2:
			return
		var selected: Dictionary = {}
		for frame_value in read_result["values"]:
			var frame: Dictionary = frame_value
			var frame_id := int(frame.get("frame_id", -1))
			if frame_id >= int(frame_range[0]) \
					and frame_id <= int(frame_range[1]):
				selected[frame_id] = frame
		var expected_count := int(frame_range[1]) - int(frame_range[0]) + 1
		if expected_count <= 0 or selected.size() != expected_count:
			_add(
				errors,
				FailureCodesScript.RECORD_REFERENCE_MISSING,
				"%s/frame_range" % operand_path,
				"Comparison operand does not contain every declared frame.")
			return
		operand_frames.append(selected)
	var left: Dictionary = operand_frames[0]
	var right: Dictionary = operand_frames[1]
	var frame_sets_match := left.size() == right.size() and not left.is_empty()
	for frame_id_value in left:
		frame_sets_match = frame_sets_match and right.has(frame_id_value)
	if not frame_sets_match:
		_add(
			errors,
			FailureCodesScript.RECORD_ORDER_INVALID,
			"/summary.json/metrics/%d/source_operands" % metric_index,
			"Comparison operand frame IDs are not one-to-one.")
		return
	var frame_ids: Array = left.keys()
	frame_ids.sort()
	var max_distance := 0.0
	for frame_id_value in frame_ids:
		var left_frame: Dictionary = left[frame_id_value]
		var right_frame: Dictionary = right[frame_id_value]
		if (
			int(left_frame.get("physics_step_id", -1))
				!= int(right_frame.get("physics_step_id", -1))
			or int(left_frame.get("capture_epoch", -1))
				!= int(right_frame.get("capture_epoch", -1))
		):
			_add(
				errors,
				FailureCodesScript.RECORD_ORDER_INVALID,
				"/summary.json/metrics/%d/source_operands" % metric_index,
				"Comparison frames disagree on step or capture epoch.")
			return
		var left_value: Variant = _resolve_json_pointer(
			left_frame, String(operands[0]["field"]))
		var right_value: Variant = _resolve_json_pointer(
			right_frame, String(operands[1]["field"]))
		var left_vector := _json_vec3(left_value)
		var right_vector := _json_vec3(right_value)
		if not left_vector.is_finite() or not right_vector.is_finite():
			_add(
				errors,
				FailureCodesScript.EVIDENCE_INVALID,
				"/summary.json/metrics/%d/source_operands" % metric_index,
				"Comparison operand field is absent or non-finite.")
			return
		max_distance = maxf(max_distance, left_vector.distance_to(right_vector))
	var recorded := float(metric.get("value", NAN))
	var tolerance := maxf(
		float(metric.get("recompute_absolute_tolerance", 0.0)),
		maxf(1.0e-12, absf(max_distance) * 1.0e-12))
	if not is_finite(recorded) or absf(recorded - max_distance) > tolerance:
		_add(
			errors,
			FailureCodesScript.EVIDENCE_INVALID,
			"/summary.json/metrics/%d/value" % metric_index,
			"Stored comparison metric does not reproduce from its sealed operands.")


static func _resolve_json_pointer(root: Variant, pointer: String) -> Variant:
	if pointer.is_empty() or not pointer.begins_with("/"):
		return null
	var cursor: Variant = root
	for raw_segment in pointer.trim_prefix("/").split("/"):
		var segment := String(raw_segment).replace("~1", "/").replace("~0", "~")
		if cursor is Dictionary and (cursor as Dictionary).has(segment):
			cursor = (cursor as Dictionary)[segment]
		elif cursor is Array and segment.is_valid_int() \
				and int(segment) >= 0 and int(segment) < (cursor as Array).size():
			cursor = (cursor as Array)[int(segment)]
		else:
			return null
	return cursor


static func _json_vec3(value: Variant) -> Vector3:
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3(INF, INF, INF)


static func _read_jsonl_values(path: String) -> Dictionary:
	var values: Array = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "values": values}
	while file.get_position() < file.get_length():
		var line := file.get_line()
		var value = JSON.parse_string(line)
		if typeof(value) != TYPE_DICTIONARY:
			return {"ok": false, "values": values}
		values.append(value)
	return {"ok": true, "values": values}


static func _check_run_id(
		run_id: String,
		artifact: Dictionary,
		path: String,
		errors: Array) -> void:
	if String(artifact.get("run_id", "")) != run_id:
		_add(
			errors,
			FailureCodesScript.RUN_ID_MISMATCH,
			path.path_join("run_id"),
			"Artifact run_id does not match manifest.")


static func _list_immutable_artifacts(directory: String) -> Array[String]:
	var artifacts: Array[String] = []
	var access := DirAccess.open(directory)
	if access == null:
		return artifacts
	# Structural validation must not silently sanitize dot-prefixed payloads.
	# Required validation also checks the authenticated snapshot inventory,
	# but keeping both paths closed prevents mode-dependent bundle semantics.
	access.include_hidden = true
	access.list_dir_begin()
	var name := access.get_next()
	while not name.is_empty():
		if not access.current_is_dir() \
				and name != "checksums.json" \
				and not name.ends_with(".tmp") \
				and not name.ends_with(".previous"):
			artifacts.append(name)
		name = access.get_next()
	access.list_dir_end()
	artifacts.sort()
	return artifacts


static func _sha256_file(path: String) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	const CHUNK_SIZE := 65536
	while file.get_position() < file.get_length():
		var remaining := file.get_length() - file.get_position()
		context.update(file.get_buffer(mini(CHUNK_SIZE, remaining)))
	return "sha256:%s" % context.finish().hex_encode()


static func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_length() if file != null else -1


static func _authenticated_snapshot_failure(
		bundle_path: String,
		failure: Dictionary,
		phase: String) -> Dictionary:
	var errors: Array = []
	var code := String(failure.get(
		"failure_code",
		failure.get("code", FailureCodesScript.EVIDENCE_INVALID)))
	if code.is_empty():
		code = FailureCodesScript.EVIDENCE_INVALID
	var message := String(failure.get(
		"message",
		"Required authenticated snapshot validation failed."))
	_add(
		errors,
		code,
		"/authenticated_snapshot/%s" % phase,
		message)
	var absolute := _absolute(bundle_path)
	var is_partial := absolute.trim_suffix("/").trim_suffix(
		"\\").get_file().ends_with(".partial")
	return _result(
		errors,
		[],
		[],
		{
			"record_counts": {},
			"artifact_count": 0,
			"semantic_verifiers": {},
			"publication_attestation": {},
			"authenticated_snapshot": {
				"ok": false,
				"source_bundle_path": absolute,
				"source_is_partial": is_partial,
				"phase": phase,
				"failure_code": code,
				"message": message,
				"read_policy":
					"authenticated_read_once_then_private_validation_v1",
				"private_copy_removed": bool(failure.get(
					"private_copy_removed", true)),
			},
		},
		false,
		false,
		is_partial)


static func _reserve_validation_snapshot_parent() -> Dictionary:
	var temp_root := _absolute(OS.get_temp_dir()).simplify_path()
	var project_root := _absolute(
		ProjectSettings.globalize_path("res://")).simplify_path()
	if temp_root.is_empty() \
			or temp_root == project_root \
			or _path_is_descendant(temp_root, project_root):
		return {
			"ok": false,
			"failure_code": FailureCodesScript.EVIDENCE_INVALID,
			"message": "OS temp root is unavailable or overlaps the repository.",
		}
	var base := temp_root.path_join(
		"sporespore_lab_authenticated_validation_v1")
	var base_error := DirAccess.make_dir_recursive_absolute(base)
	if base_error != OK:
		return {
			"ok": false,
			"failure_code": FailureCodesScript.EVIDENCE_INVALID,
			"message": "Authenticated validation temp root could not be created.",
		}
	for attempt in 64:
		var candidate := base.path_join(
			"capture_%d_%d_%d" % [
				OS.get_process_id(),
				Time.get_ticks_usec(),
				attempt,
			])
		var create_error := DirAccess.make_dir_absolute(candidate)
		if create_error == OK:
			return {
				"ok": true,
				"parent_path": candidate,
			}
		if create_error != ERR_ALREADY_EXISTS:
			return {
				"ok": false,
				"failure_code": FailureCodesScript.EVIDENCE_INVALID,
				"message":
					"Authenticated validation snapshot parent could not be reserved.",
			}
	return {
		"ok": false,
		"failure_code": FailureCodesScript.RUN_RESERVATION_COLLISION,
		"message": "Authenticated validation snapshot parent allocation exhausted.",
	}


static func _remove_validation_snapshot_tree(parent_path: String) -> bool:
	# Cleanup is deliberately bounded to the exact two-level layout created by
	# materialize_to_empty_temp_parent(). Never recurse through an unexpected
	# directory or a caller-controlled path.
	var parent := _absolute(parent_path).simplify_path()
	var temp_root := _absolute(OS.get_temp_dir()).simplify_path()
	if parent.is_empty() \
			or temp_root.is_empty() \
			or not _path_is_descendant(parent, temp_root) \
			or not parent.get_file().begins_with("capture_") \
			or parent.get_base_dir().get_file() \
				!= "sporespore_lab_authenticated_validation_v1":
		return false
	if not DirAccess.dir_exists_absolute(parent):
		return true
	var parent_dir := DirAccess.open(parent)
	if parent_dir == null:
		return false
	var children: Array[Dictionary] = []
	parent_dir.include_hidden = true
	parent_dir.list_dir_begin()
	var child_name := parent_dir.get_next()
	while not child_name.is_empty():
		children.append({
			"name": child_name,
			"is_directory": parent_dir.current_is_dir(),
		})
		child_name = parent_dir.get_next()
	parent_dir.list_dir_end()
	for child_value in children:
		var child: Dictionary = child_value
		var child_path := parent.path_join(String(child["name"]))
		if not bool(child["is_directory"]):
			if DirAccess.remove_absolute(child_path) != OK:
				return false
			continue
		var bundle_dir := DirAccess.open(child_path)
		if bundle_dir == null:
			return false
		var artifacts: Array[Dictionary] = []
		bundle_dir.include_hidden = true
		bundle_dir.list_dir_begin()
		var artifact_name := bundle_dir.get_next()
		while not artifact_name.is_empty():
			artifacts.append({
				"name": artifact_name,
				"is_directory": bundle_dir.current_is_dir(),
			})
			artifact_name = bundle_dir.get_next()
		bundle_dir.list_dir_end()
		for artifact_value in artifacts:
			var artifact: Dictionary = artifact_value
			if bool(artifact["is_directory"]):
				return false
			if DirAccess.remove_absolute(
					child_path.path_join(String(artifact["name"]))) != OK:
				return false
		if DirAccess.remove_absolute(child_path) != OK:
			return false
	return DirAccess.remove_absolute(parent) == OK


static func _path_is_descendant(candidate: String, parent: String) -> bool:
	var child_identity := candidate.replace("\\", "/").trim_suffix(
		"/").to_lower()
	var parent_identity := parent.replace("\\", "/").trim_suffix(
		"/").to_lower()
	return child_identity.begins_with(parent_identity + "/")


static func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path).replace("\\", "/")


static func _merge_result_errors(target: Array, result: Dictionary, prefix: String) -> void:
	if result["ok"]:
		return
	for error_value in result.get("errors", []):
		var error: Dictionary = error_value.duplicate()
		var child_path := String(error.get("path", "/"))
		error["path"] = prefix if child_path == "/" else "%s%s" % [prefix, child_path]
		target.append(error)


static func _add(target: Array, code: String, path: String, message: String) -> void:
	target.append({"code": code, "path": path, "message": message})


static func _result(
		errors: Array,
		blockers: Array,
		warnings: Array,
		stats: Dictionary,
		can_finalize: bool,
		can_promote: bool,
		is_partial: bool) -> Dictionary:
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"promotion_blockers": blockers,
		"warnings": warnings,
		"stats": stats,
		"can_finalize": can_finalize,
		"can_promote": can_promote,
		"is_partial": is_partial,
	}
