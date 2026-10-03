extends SceneTree

const AttestationScript := preload(
	"res://scripts/lab/publication_attestation.gd")
const AttestationTestHelperScript := preload(
	"res://tests/helpers/lab_attestation_test_helper.gd")
const CanonicalJsonScript := preload(
	"res://scripts/lab/canonical_json.gd")
const FailureCodesScript := preload(
	"res://scripts/lab/failure_codes.gd")
const BundleValidatorScript := preload(
	"res://scripts/lab/run_bundle_validator.gd")
const SnapshotScript := preload(
	"res://scripts/lab/attested_bundle_snapshot.gd")

const HASH := \
	"sha256:0000000000000000000000000000000000000000000000000000000000000000"
const FIXED_TIME := "2026-07-19T20:00:00Z"

var _passed := 0
var _failed := 0
var _bundle_root := ""
var _trust_root := ""
var _run_id := ""
var _required_validation: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Authenticated read-once bundle snapshot tests ===")
	if not _build_attested_fixture():
		_cleanup()
		print("=== %d passed, %d failed ===" % [_passed, _failed])
		quit(1)
		return
	_test_valid_capture_and_reads()
	_test_private_temp_materialization()
	_test_forged_validation_metadata_is_rejected()
	_test_missing_and_unindexed_artifacts_fail_closed()
	_test_required_validation_preserves_partial_source_state()
	_test_snapshot_survives_coherent_path_mutation()
	_test_snapshot_results_are_immutable()
	_cleanup()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _build_attested_fixture() -> bool:
	print("- constructs a real HMAC-attested test bundle")
	var token := "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_bundle_root = ProjectSettings.globalize_path(
		"res://.tmp/lab_snapshot_tests/%s" % token).replace("\\", "/")
	_run_id = "snapshot-%s" % token
	DirAccess.make_dir_recursive_absolute(_bundle_root)
	var trust := AttestationTestHelperScript.create_trust_root(
		"attested_snapshot")
	_check(bool(trust.get("ok", false)),
		"external test trust root initializes")
	if not bool(trust.get("ok", false)):
		return false
	_trust_root = String(trust["trust_root"])
	_write_fixture("original")
	var attested := AttestationScript.attest_with_test_trust_root(
		_bundle_root, _trust_root, FIXED_TIME)
	_check(bool(attested.get("ok", false)),
		"fixture receives a detached HMAC receipt")
	if not bool(attested.get("ok", false)):
		printerr("    ", attested)
		return false
	var verified := AttestationScript.verify_with_test_trust_root(
		_bundle_root, _trust_root)
	_check(bool(verified.get("ok", false))
		and String(verified.get("trust_mode", "")) == "test",
		"fixture receipt verifies through the explicit test trust boundary")
	if not bool(verified.get("ok", false)):
		printerr("    ", verified)
		return false

	# This is the exact public shape produced after
	# validate_bundle(..., {"attestation_requirement": "required"}).  The
	# cryptographic witness itself comes from the real verifier above; this
	# focused unit deliberately avoids coupling to unrelated L0 semantics.
	_required_validation = {
		"ok": true,
		"errors": [],
		"promotion_blockers": [],
		"warnings": [],
		"stats": {
			"publication_attestation": verified,
		},
		"can_finalize": true,
		"can_promote": false,
		"is_partial": false,
	}
	return true


func _test_valid_capture_and_reads() -> void:
	print("- captures every indexed artifact into one authenticated memory image")
	var captured := SnapshotScript.capture_verified(
		_bundle_root, {"attestation_test_root": _trust_root})
	if not bool(captured.get("ok", false)):
		printerr("    ", captured)
	_check(bool(captured.get("ok", false)),
		"valid required-attestation witness captures")
	if not bool(captured.get("ok", false)):
		return
	var compatibility_capture := SnapshotScript.capture(
		_bundle_root, _required_validation)
	_check(
		bool(compatibility_capture.get("ok", false)),
		"completed-validation compatibility API independently re-verifies its witness")
	var snapshot: LabAttestedBundleSnapshot = captured["snapshot"]
	var names: Array = snapshot.artifact_names()
	_check(
		names == [
			"document.json",
			"empty.jsonl",
			"manifest.json",
			"metadata.json",
			"stream.jsonl",
		],
		"artifact inventory is sorted and excludes self-hashed checksums.json")
	var document: Dictionary = snapshot.read_json_object("document.json")
	_check(
		document["ok"]
			and String(document["value"]["variant"]) == "original",
		"JSON object parses from captured bytes")
	var stream: Dictionary = snapshot.read_jsonl("stream.jsonl", true)
	_check(
		stream["ok"]
			and int(stream["record_count"]) == 2
			and String(stream["records"][1]["variant"]) == "original",
		"JSONL parses from captured bytes and matches sealed record count")
	var empty_stream: Dictionary = snapshot.read_jsonl(
		"empty.jsonl", true)
	_check(
		empty_stream["ok"]
			and int(empty_stream["record_count"]) == 0
			and empty_stream["records"].is_empty(),
		"zero-byte authenticated stream hashes, stores, and parses without engine errors")
	var optional: Dictionary = snapshot.read_jsonl("events.jsonl", false)
	_check(
		optional["ok"] and optional["records"].is_empty(),
		"missing optional stream returns one frozen empty result")
	var required: Dictionary = snapshot.read_jsonl("events.jsonl", true)
	_check(
		not required["ok"]
			and required["failure_code"]
				== FailureCodesScript.ARTIFACT_MISSING,
		"missing required stream has a stable machine-readable failure")
	var checksums: Dictionary = snapshot.checksums()
	var witness: Dictionary = snapshot.publication_witness()
	_check(
		String(witness["checksums_sha256"])
				== snapshot.sha256("checksums.json")
			and String(witness["manifest_sha256"])
				== snapshot.sha256("manifest.json")
			and int(witness["artifact_count"]) == names.size(),
		"public witness, index digest, manifest digest, and count stay bound")
	_check(
		snapshot.bytes_count("document.json") > 0
			and snapshot.bytes_count("checksums.json") > 0
			and snapshot.bytes_count("not-indexed.json") == -1
			and snapshot.sha256("not-indexed.json").is_empty(),
		"hash and byte-count accessors reveal metadata only")
	_check(
		not snapshot.has_method("read_bytes")
			and not snapshot.has_method("raw_buffer")
			and checksums["artifacts"].has("document.json"),
		"snapshot exposes no mutable raw-buffer API")


func _test_private_temp_materialization() -> void:
	print("- materializes exact snapshot bytes only below an empty private temp parent")
	var captured := SnapshotScript.capture_verified(
		_bundle_root, {"attestation_test_root": _trust_root})
	_check(bool(captured.get("ok", false)),
		"verified snapshot is available for private materialization")
	if not bool(captured.get("ok", false)):
		return
	var snapshot: LabAttestedBundleSnapshot = captured["snapshot"]
	var parent := OS.get_temp_dir().path_join(
		"sporespore_snapshot_materialize_%d_%d" % [
			OS.get_process_id(),
			Time.get_ticks_usec(),
		]).replace("\\", "/").simplify_path()
	DirAccess.make_dir_recursive_absolute(parent)
	var materialized: Dictionary = snapshot.materialize_to_empty_temp_parent(
		parent, _run_id)
	if not bool(materialized.get("ok", false)):
		printerr("    ", materialized)
	_check(bool(materialized.get("ok", false)),
		"snapshot reserves a new authenticated run directory")
	if not bool(materialized.get("ok", false)):
		AttestationTestHelperScript.remove_tree(parent)
		return
	var copied_path := String(materialized["bundle_path"])
	var copied_verification := AttestationScript.verify_with_test_trust_root(
		copied_path, _trust_root)
	_check(
		bool(copied_verification.get("ok", false))
			and String(copied_verification["checksums_sha256"])
				== snapshot.sha256("checksums.json")
			and FileAccess.get_file_as_bytes(
				copied_path.path_join("document.json"))
				== FileAccess.get_file_as_bytes(
					_bundle_root.path_join("document.json")),
		"materialized copy retains the same receipt-valid exact bytes")
	var second := snapshot.materialize_to_empty_temp_parent(
		parent, _run_id)
	_check(
		not second["ok"]
			and second["failure_code"]
				== FailureCodesScript.ARTIFACT_UNDECLARED,
		"nonempty materialization parent is never reused or overwritten")
	AttestationTestHelperScript.remove_tree(parent)


func _test_forged_validation_metadata_is_rejected() -> void:
	print("- rejects validation metadata that is not bound to captured bytes")
	var injected_options := SnapshotScript.capture_verified(
		_bundle_root,
		{
			"attestation_test_root": _trust_root,
			"publication_attestation": _required_validation[
				"stats"]["publication_attestation"],
		})
	_check(
		not injected_options["ok"]
			and injected_options["failure_code"]
				== FailureCodesScript.EVIDENCE_INVALID,
		"preferred API rejects caller-injected authority options")
	var forged_checksum := _required_validation.duplicate(true)
	forged_checksum["stats"]["publication_attestation"][
		"checksums_sha256"] = HASH
	var checksum_result := SnapshotScript.capture(
		_bundle_root, forged_checksum)
	_check(
		not checksum_result["ok"]
			and checksum_result["failure_code"]
				== FailureCodesScript.PUBLICATION_ENVELOPE_MISMATCH,
		"forged authenticated checksums digest fails before artifact reads")

	var forged_manifest := _required_validation.duplicate(true)
	forged_manifest["stats"]["publication_attestation"][
		"manifest_sha256"] = HASH
	var manifest_result := SnapshotScript.capture(
		_bundle_root, forged_manifest)
	_check(
		not manifest_result["ok"]
			and manifest_result["failure_code"]
				== FailureCodesScript.PUBLICATION_ENVELOPE_MISMATCH,
		"forged authenticated manifest digest fails closed")

	var forged_count := _required_validation.duplicate(true)
	forged_count["stats"]["publication_attestation"][
		"artifact_count"] = 99
	var count_result := SnapshotScript.capture(
		_bundle_root, forged_count)
	_check(
		not count_result["ok"]
			and count_result["failure_code"]
				== FailureCodesScript.PUBLICATION_ENVELOPE_MISMATCH,
		"forged authenticated artifact count fails closed")

	var no_attestation := _required_validation.duplicate(true)
	no_attestation["stats"]["publication_attestation"]["ok"] = false
	var no_attestation_result := SnapshotScript.capture(
		_bundle_root, no_attestation)
	_check(
		not no_attestation_result["ok"]
			and no_attestation_result["failure_code"]
				== FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
		"non-attested structural validation cannot cross snapshot boundary")


func _test_missing_and_unindexed_artifacts_fail_closed() -> void:
	print("- detects post-validation path changes before a snapshot is admitted")
	var stream_path := _bundle_root.path_join("stream.jsonl")
	var original_stream := FileAccess.get_file_as_bytes(stream_path)
	DirAccess.remove_absolute(stream_path)
	var missing := SnapshotScript.capture_verified(
		_bundle_root, {"attestation_test_root": _trust_root})
	_check(
		not missing["ok"]
			and missing["failure_code"]
				== FailureCodesScript.ARTIFACT_MISSING,
		"indexed artifact removed after validation is rejected")
	_write_bytes(stream_path, original_stream)

	var rogue_path := _bundle_root.path_join("unindexed.json")
	_write_json(rogue_path, {"not": "sealed"})
	var unindexed := SnapshotScript.capture_verified(
		_bundle_root, {"attestation_test_root": _trust_root})
	_check(
		not unindexed["ok"]
			and unindexed["failure_code"]
				== FailureCodesScript.ARTIFACT_UNDECLARED,
		"unindexed artifact added after validation is rejected")
	DirAccess.remove_absolute(rogue_path)

	var hidden_rogue_path := _bundle_root.path_join(
		".unindexed-hidden.json")
	_write_json(hidden_rogue_path, {"not": "sealed"})
	var hidden_unindexed := SnapshotScript.capture_verified(
		_bundle_root, {"attestation_test_root": _trust_root})
	_check(
		not hidden_unindexed["ok"]
			and hidden_unindexed["failure_code"]
				== FailureCodesScript.ARTIFACT_UNDECLARED,
		"hidden unindexed artifact is part of the closed bundle inventory")
	DirAccess.remove_absolute(hidden_rogue_path)

	var hidden_directory_path := _bundle_root.path_join(".unindexed-dir")
	DirAccess.make_dir_absolute(hidden_directory_path)
	var hidden_directory := SnapshotScript.capture_verified(
		_bundle_root, {"attestation_test_root": _trust_root})
	_check(
		not hidden_directory["ok"]
			and hidden_directory["failure_code"]
				== FailureCodesScript.ARTIFACT_UNDECLARED,
		"hidden directory is part of the closed flat bundle inventory")
	DirAccess.remove_absolute(hidden_directory_path)

	var original_document := FileAccess.get_file_as_bytes(
		_bundle_root.path_join("document.json"))
	_write_json(
		_bundle_root.path_join("document.json"),
		{"schema": "snapshot.fixture.v1", "variant": "raced"})
	var stale := SnapshotScript.capture_verified(
		_bundle_root, {"attestation_test_root": _trust_root})
	_check(
		not stale["ok"]
			and stale["failure_code"]
				== FailureCodesScript.CHECKSUM_MISMATCH,
		"artifact mutation between validation and capture is detected")
	_write_bytes(
		_bundle_root.path_join("document.json"), original_document)


func _test_required_validation_preserves_partial_source_state() -> void:
	print("- preserves source .partial policy across private materialization")
	var original_root := _bundle_root
	var partial_root := original_root + ".partial"
	var rename_error := DirAccess.rename_absolute(original_root, partial_root)
	_check(rename_error == OK,
		"attested fixture can be presented through a .partial source path")
	if rename_error != OK:
		return
	_bundle_root = partial_root

	var strict := BundleValidatorScript.validate_bundle(
		partial_root,
		{
			"attestation_requirement": "required",
			"attestation_test_root": _trust_root,
		})
	_check(
		bool(strict.get("is_partial", false))
			and not bool(strict.get("can_finalize", true))
			and not bool(strict.get("can_promote", true)),
		"required validation never sanitizes strict .partial policy state")
	var inspection := BundleValidatorScript.validate_bundle(
		partial_root,
		{
			"allow_partial": true,
			"attestation_requirement": "required",
			"attestation_test_root": _trust_root,
		})
	var inspection_stats: Dictionary = inspection.get("stats", {})
	var snapshot_stats: Dictionary = inspection_stats.get(
		"authenticated_snapshot", {})
	_check(
		bool(inspection.get("is_partial", false))
			and not bool(inspection.get("can_finalize", true))
			and not bool(inspection.get("can_promote", true))
			and bool(snapshot_stats.get("source_is_partial", false)),
		"allow_partial remains inspection-only after authenticated capture")

	var restore_error := DirAccess.rename_absolute(partial_root, original_root)
	_check(restore_error == OK,
		"partial-path fixture restores for remaining snapshot tests")
	if restore_error == OK:
		_bundle_root = original_root


func _test_snapshot_survives_coherent_path_mutation() -> void:
	print("- proves later coherent disk replacement cannot alter captured values")
	var captured := SnapshotScript.capture_verified(
		_bundle_root, {"attestation_test_root": _trust_root})
	_check(bool(captured.get("ok", false)),
		"baseline snapshot captures before path replacement")
	if not bool(captured.get("ok", false)):
		return
	var snapshot: LabAttestedBundleSnapshot = captured["snapshot"]
	var original_checksum_digest: String = snapshot.sha256(
		"checksums.json")
	_write_fixture("replacement")
	var on_disk_document := _read_json(
		_bundle_root.path_join("document.json"))
	var retained_document: Dictionary = snapshot.read_json_object(
		"document.json")
	var retained_stream: Dictionary = snapshot.read_jsonl(
		"stream.jsonl", true)
	_check(
		on_disk_document["ok"]
			and String(on_disk_document["value"]["variant"])
				== "replacement",
		"bundle path now contains a coherent replacement")
	_check(
		retained_document["ok"]
			and String(retained_document["value"]["variant"]) == "original"
			and retained_stream["ok"]
			and String(retained_stream["records"][0]["variant"])
				== "original",
		"snapshot parsers retain only the originally authenticated bytes")
	_check(
		snapshot.sha256("checksums.json") == original_checksum_digest
			and snapshot.sha256("checksums.json")
				!= "sha256:%s" % FileAccess.get_sha256(
					_bundle_root.path_join("checksums.json")),
		"snapshot identity is independent of later path contents")

	# Restore exact originally attested bytes for subsequent immutability checks.
	_write_fixture("original")


func _test_snapshot_results_are_immutable() -> void:
	print("- freezes all public structured values and detaches caller copies")
	var captured := SnapshotScript.capture_verified(
		_bundle_root, {"attestation_test_root": _trust_root})
	_check(bool(captured.get("ok", false)),
		"restored exact bytes capture again")
	if not bool(captured.get("ok", false)):
		return
	var snapshot: LabAttestedBundleSnapshot = captured["snapshot"]
	var names: Array = snapshot.artifact_names()
	var checksums: Dictionary = snapshot.checksums()
	var witness: Dictionary = snapshot.publication_witness()
	var document_result: Dictionary = snapshot.read_json_object(
		"document.json")
	var document: Dictionary = document_result["value"]
	var stream_result: Dictionary = snapshot.read_jsonl(
		"stream.jsonl", true)
	_check(
		names.is_read_only()
			and checksums.is_read_only()
			and (checksums["artifacts"] as Dictionary).is_read_only()
			and witness.is_read_only()
			and document_result.is_read_only()
			and document.is_read_only()
			and stream_result.is_read_only()
			and (stream_result["records"] as Array).is_read_only(),
		"every public collection is recursively read-only")

	var caller_copy: Dictionary = document.duplicate(true)
	caller_copy["variant"] = "caller-mutated-copy"
	var reread: Dictionary = snapshot.read_json_object("document.json")
	_check(
		String(reread["value"]["variant"]) == "original",
		"mutating a caller-owned duplicate cannot alter snapshot state")


func _write_fixture(variant: String) -> void:
	var manifest := {
		"schema": "sporespore.lab.manifest.v1",
		"run_id": _run_id,
		"status": "COMPLETE",
		"experiment_id": "SNAPSHOT_READ_ONCE_FIXTURE",
		"schema_set": "sporespore.lab.schemas.v1",
		"recorder_version": "snapshot-test-%s" % variant,
		"expanded_spec_sha256": HASH,
		"resolved_configuration_sha256": HASH,
		"applied_configuration_sha256": HASH,
		"dirty_worktree": false,
		"execution_mode": "development",
		"reproducibility": "partial_dirty_source",
		"units": "SI",
		"started_utc": FIXED_TIME,
		"finalized_utc": "2026-07-19T20:00:01Z",
		"required_artifacts": [
			"manifest.json",
			"document.json",
			"empty.jsonl",
			"metadata.json",
			"stream.jsonl",
		],
	}
	# publication_attestation validates the owned manifest schema but does not
	# interpret required_artifacts as the bundle validator does.  Keep every
	# actual immutable artifact in checksums.json below.
	_write_json(_bundle_root.path_join("manifest.json"), manifest)
	_write_json(_bundle_root.path_join("document.json"), {
		"schema": "snapshot.fixture.v1",
		"variant": variant,
	})
	_write_json(_bundle_root.path_join("metadata.json"), {
		"schema": "snapshot.metadata.v1",
		"variant": variant,
	})
	_write_text(_bundle_root.path_join("empty.jsonl"), "")
	_write_text(
		_bundle_root.path_join("stream.jsonl"),
		CanonicalJsonScript.stringify({
			"index": 0,
			"variant": variant,
		}) + "\n"
		+ CanonicalJsonScript.stringify({
			"index": 1,
			"variant": variant,
		}) + "\n")
	var artifacts: Dictionary = {}
	for artifact_name_value in [
		"manifest.json",
		"document.json",
		"empty.jsonl",
		"metadata.json",
		"stream.jsonl",
	]:
		var artifact_name := String(artifact_name_value)
		var path := _bundle_root.path_join(artifact_name)
		var is_jsonl := artifact_name.ends_with(".jsonl")
		artifacts[artifact_name] = {
			"sha256": "sha256:%s" % FileAccess.get_sha256(path),
			"bytes": FileAccess.get_file_as_bytes(path).size(),
			"kind": "jsonl" if is_jsonl else "json",
			"records": (
				0
				if artifact_name == "empty.jsonl"
				else (2 if is_jsonl else null)
			),
		}
	_write_json(_bundle_root.path_join("checksums.json"), {
		"schema": "sporespore.lab.checksums.v1",
		"run_id": _run_id,
		"algorithm": "sha256",
		"artifact_count": artifacts.size(),
		"artifacts": artifacts,
	})


func _write_json(path: String, value: Dictionary) -> void:
	_write_text(path, CanonicalJsonScript.stringify(value) + "\n")


func _write_text(path: String, value: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(value)
	file.flush()
	file.close()


func _write_bytes(path: String, value: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(value)
	file.flush()
	file.close()


func _read_json(path: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK \
			or typeof(parser.data) != TYPE_DICTIONARY:
		return {"ok": false}
	return {
		"ok": true,
		"value": parser.data,
	}


func _cleanup() -> void:
	_remove_tree(_bundle_root)
	if not _trust_root.is_empty():
		AttestationTestHelperScript.remove_tree(_trust_root)


func _remove_tree(path: String) -> void:
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.include_hidden = true
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child := path.path_join(name)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)
