class_name LabAttestedBundleSnapshot
extends RefCounted

## Authenticated, read-once evidence snapshot.
##
## A normal validate-then-read flow has an ABA race: a bundle writer can swap
## bytes after validation, let a consumer read some replacement artifacts, and
## restore the original bytes before a second validation.  This boundary closes
## that gap by binding every byte used by a consumer to the authenticated
## checksums.json envelope returned by detached publication verification.
##
## capture_verified() authenticates against the fixed production trust store
## (or an explicitly named test root), then performs exactly one snapshot
## content read of checksums.json and exactly one snapshot content read of each
## indexed artifact.  Hashing and parsing use those in-memory bytes; no read
## method reopens the bundle.  Exact bytes are retained as private base64
## strings so callers cannot obtain a mutable raw buffer.
##
## Trust boundary: use capture_verified() for every consuming path.  The
## lower-level capture_from_attestation() and capture() entry points exist for
## tightly scoped composition/testing and independently re-verify any supplied
## public witness before accepting it.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const FailureCodesScript := preload("res://scripts/lab/failure_codes.gd")
const PublicationAttestationScript := preload(
	"res://scripts/lab/publication_attestation.gd")

const CHECKSUMS_NAME := "checksums.json"
const MANIFEST_NAME := "manifest.json"
const CHECKSUMS_SCHEMA := "sporespore.lab.checksums.v1"
const ATTESTATION_ALGORITHM := "hmac-sha256"

# GDScript has no access-control keyword.  These underscore-prefixed containers
# are therefore additionally made read-only, and their payload values are
# immutable Strings rather than externally mutable PackedByteArrays.
var _encoded_payloads: Dictionary = {}
var _artifact_metadata: Dictionary = {}
var _artifact_name_list: Array = []
var _captured_checksums: Dictionary = {}
var _captured_witness: Dictionary = {}
var _checksums_sha256 := ""
var _checksums_bytes := -1


## Preferred security boundary.  Callers may select only the explicit test
## trust root used by automated tests; production always resolves the fixed
## trust store inside LabPublicationAttestation.
static func capture_verified(
		bundle_path: String,
		validation_options: Dictionary = {}) -> Dictionary:
	for option_value in validation_options:
		var option := String(option_value)
		if option != "attestation_test_root":
			return _failure(
				FailureCodesScript.EVIDENCE_INVALID,
				"Authenticated snapshot received an unsupported verification option.",
				"/validation_options/%s" % option)
	var test_root := String(validation_options.get(
		"attestation_test_root", "")).strip_edges()
	var verification: Dictionary = (
		PublicationAttestationScript.verify_with_test_trust_root(
			bundle_path, test_root)
		if not test_root.is_empty()
		else PublicationAttestationScript.verify_production(bundle_path))
	if not bool(verification.get("ok", false)):
		return _failure(
			String(verification.get(
				"failure_code",
				verification.get(
					"code",
					FailureCodesScript.PUBLICATION_RECEIPT_INVALID))),
			"Bundle failed detached publication verification before snapshot capture.",
			"/publication_attestation",
			{"verification": _safe_verification_failure(verification)})
	var witness_result := _validated_attestation(verification)
	if not bool(witness_result.get("ok", false)):
		return witness_result
	return _capture_bound(bundle_path, witness_result["witness"])


## Composition seam for a verifier that has just returned successfully.  This
## method independently re-verifies the fixed production receipt, or derives
## the already-explicit test root from the receipt path and re-verifies there.
## It then requires the supplied public witness to match that fresh result.
static func capture_from_attestation(
		bundle_path: String,
		successful_publication_verification: Dictionary) -> Dictionary:
	var supplied_result := _validated_attestation(
		successful_publication_verification)
	if not bool(supplied_result.get("ok", false)):
		return supplied_result
	var reverified_result := _reverify_supplied_attestation(
		bundle_path,
		successful_publication_verification)
	if not bool(reverified_result.get("ok", false)):
		return reverified_result
	var actual_result := _validated_attestation(
		reverified_result["verification"])
	if not bool(actual_result.get("ok", false)):
		return actual_result
	if supplied_result["witness"] != actual_result["witness"]:
		return _failure(
			FailureCodesScript.PUBLICATION_ENVELOPE_MISMATCH,
			"Supplied publication witness does not match independent verification.",
			"/publication_attestation")
	return _capture_bound(
		bundle_path,
		actual_result["witness"])


## Compatibility seam for callers that already possess the complete result of
## required bundle validation.  New consuming boundaries should instead call
## capture_verified().  This overload extracts the witness and sends it through
## capture_from_attestation(), which independently authenticates it again.
static func capture(
		bundle_path: String,
		completed_required_validation: Dictionary) -> Dictionary:
	var validation_result := _validated_attestation_witness(
		completed_required_validation)
	if not bool(validation_result.get("ok", false)):
		return validation_result
	return capture_from_attestation(
		bundle_path,
		(completed_required_validation["stats"] as Dictionary)[
			"publication_attestation"])


static func _capture_bound(
		bundle_path: String,
		witness: Dictionary) -> Dictionary:
	var absolute_path := _normalized_absolute(bundle_path)
	if absolute_path.is_empty() \
			or not DirAccess.dir_exists_absolute(absolute_path):
		return _failure(
			FailureCodesScript.ARTIFACT_MISSING,
			"Snapshot source is not an existing absolute bundle directory.",
			"/")

	# This is the sole checksums.json content read.  Every later operation uses
	# this exact PackedByteArray or its immutable encoded/text derivatives.
	var checksum_read := _read_file_once(
		absolute_path.path_join(CHECKSUMS_NAME))
	if not bool(checksum_read.get("ok", false)):
		return checksum_read
	var checksum_bytes: PackedByteArray = checksum_read["bytes"]
	var checksum_digest := _sha256_bytes(checksum_bytes)
	if checksum_digest != String(witness["checksums_sha256"]):
		return _failure(
			FailureCodesScript.PUBLICATION_ENVELOPE_MISMATCH,
			"Captured checksums.json bytes do not match the authenticated envelope.",
			"/checksums.json",
			{
				"expected_sha256": witness["checksums_sha256"],
				"actual_sha256": checksum_digest,
			})
	var checksum_parse := _parse_json_object_bytes(
		checksum_bytes, CHECKSUMS_NAME)
	if not bool(checksum_parse.get("ok", false)):
		return checksum_parse
	var checksums: Dictionary = checksum_parse["value"]
	var index_result := _validate_checksum_index(checksums, witness)
	if not bool(index_result.get("ok", false)):
		return index_result
	var artifacts: Dictionary = checksums["artifacts"]
	var names := artifacts.keys()
	names.sort()

	# A completed bundle is flat and closed: any regular file or directory not
	# named by the authenticated index is rejected.  Enumeration does not read
	# file content and therefore does not violate the one-read rule.
	var inventory_result := _validate_directory_inventory(
		absolute_path, names)
	if not bool(inventory_result.get("ok", false)):
		return inventory_result

	var encoded_payloads: Dictionary = {
		CHECKSUMS_NAME: _encode_bytes(checksum_bytes),
	}
	var metadata: Dictionary = {}
	var manifest_digest := ""
	for name_value in names:
		var artifact_name := String(name_value)
		var entry: Dictionary = artifacts[name_value]
		var artifact_read := _read_file_once(
			absolute_path.path_join(artifact_name))
		if not bool(artifact_read.get("ok", false)):
			var detail: Dictionary = artifact_read.get("detail", {}).duplicate(true)
			detail["artifact"] = artifact_name
			return _failure(
				String(artifact_read.get(
					"failure_code", FailureCodesScript.ARTIFACT_MISSING)),
				"Indexed artifact could not be captured exactly once.",
				"/%s" % artifact_name,
				detail)
		var artifact_bytes: PackedByteArray = artifact_read["bytes"]
		var actual_bytes := artifact_bytes.size()
		var expected_bytes := _exact_nonnegative_integer(
			entry.get("bytes"))
		if expected_bytes < 0 or actual_bytes != expected_bytes:
			return _failure(
				FailureCodesScript.BYTE_COUNT_MISMATCH,
				"Captured artifact byte count does not match checksums.json.",
				"/checksums.json/artifacts/%s/bytes" % artifact_name,
				{
					"artifact": artifact_name,
					"expected_bytes": expected_bytes,
					"actual_bytes": actual_bytes,
				})
		var actual_digest := _sha256_bytes(artifact_bytes)
		var expected_digest := String(entry.get("sha256", ""))
		if actual_digest != expected_digest:
			return _failure(
				FailureCodesScript.CHECKSUM_MISMATCH,
				"Captured artifact bytes do not match checksums.json.",
				"/checksums.json/artifacts/%s/sha256" % artifact_name,
				{
					"artifact": artifact_name,
					"expected_sha256": expected_digest,
					"actual_sha256": actual_digest,
				})
		if artifact_name == MANIFEST_NAME:
			manifest_digest = actual_digest
			if manifest_digest != String(witness["manifest_sha256"]):
				return _failure(
					FailureCodesScript.PUBLICATION_ENVELOPE_MISMATCH,
					"Captured manifest.json bytes do not match the authenticated envelope.",
					"/manifest.json",
					{
						"expected_sha256": witness["manifest_sha256"],
						"actual_sha256": manifest_digest,
					})
		encoded_payloads[artifact_name] = _encode_bytes(artifact_bytes)
		metadata[artifact_name] = entry.duplicate(true)

	if manifest_digest.is_empty():
		return _failure(
			FailureCodesScript.ARTIFACT_MISSING,
			"The authenticated index does not contain manifest.json.",
			"/checksums.json/artifacts/manifest.json")

	encoded_payloads.make_read_only()
	var frozen_metadata: Dictionary = FrozenValueScript.snapshot(metadata)
	var frozen_names: Array = FrozenValueScript.snapshot(names)
	var frozen_checksums: Dictionary = FrozenValueScript.snapshot(checksums)
	var frozen_witness: Dictionary = FrozenValueScript.snapshot(witness)
	var snapshot := LabAttestedBundleSnapshot.new()
	snapshot._encoded_payloads = encoded_payloads
	snapshot._artifact_metadata = frozen_metadata
	snapshot._artifact_name_list = frozen_names
	snapshot._captured_checksums = frozen_checksums
	snapshot._captured_witness = frozen_witness
	snapshot._checksums_sha256 = checksum_digest
	snapshot._checksums_bytes = checksum_bytes.size()
	return {
		"ok": true,
		"snapshot": snapshot,
		"artifact_count": names.size(),
		"checksums_sha256": checksum_digest,
		"manifest_sha256": manifest_digest,
		"trust_mode": witness["trust_mode"],
	}


## Recreates the exact authenticated memory image below a caller-owned, empty,
## dedicated OS-temp directory.  This is the bridge for legacy validators that
## still accept only filesystem paths: validate this private copy, consume the
## snapshot object, then remove the parent directory.
##
## The parent must already exist, be empty, be a strict descendant of the OS
## temp root, and remain outside the repository.  The run directory is created
## new and never overwrites an existing path.
# gdlint: disable=max-returns
func materialize_to_empty_temp_parent(
		empty_temp_parent: String,
		run_id: String) -> Dictionary:
	var parent := _normalized_absolute(empty_temp_parent)
	var temp_root := _normalized_absolute(OS.get_temp_dir())
	var project_root := _normalized_absolute(
		ProjectSettings.globalize_path("res://"))
	if parent.is_empty() \
			or temp_root.is_empty() \
			or parent == temp_root \
			or not _is_descendant(parent, temp_root) \
			or parent == project_root \
			or _is_descendant(parent, project_root):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"Snapshot materialization parent must be a dedicated directory below OS temp.",
			"/materialization/parent")
	if not _is_safe_run_id(run_id):
		return _failure(
			FailureCodesScript.SCHEMA_INVALID,
			"Snapshot materialization run_id is not a safe stable ID.",
			"/materialization/run_id")
	if run_id != String(_captured_witness.get("run_id", "")):
		return _failure(
			FailureCodesScript.RUN_ID_MISMATCH,
			"Snapshot materialization directory must use the authenticated run_id.",
			"/materialization/run_id")
	if not DirAccess.dir_exists_absolute(parent):
		return _failure(
			FailureCodesScript.ARTIFACT_MISSING,
			"Snapshot materialization parent does not exist.",
			"/materialization/parent")
	var empty_result := _directory_is_empty(parent)
	if not bool(empty_result.get("ok", false)):
		return empty_result
	if not bool(empty_result.get("empty", false)):
		return _failure(
			FailureCodesScript.ARTIFACT_UNDECLARED,
			"Snapshot materialization parent must be empty.",
			"/materialization/parent")
	var destination := parent.path_join(run_id)
	if FileAccess.file_exists(destination) \
			or DirAccess.dir_exists_absolute(destination):
		return _failure(
			FailureCodesScript.RUN_RESERVATION_COLLISION,
			"Snapshot materialization destination already exists.",
			"/materialization/destination")
	var create_error := DirAccess.make_dir_absolute(destination)
	if create_error != OK:
		return _failure(
			FailureCodesScript.TRACE_WRITE_FAILED,
			"Snapshot materialization destination could not be reserved.",
			"/materialization/destination",
			{"error": error_string(create_error)})
	var write_names: Array = [CHECKSUMS_NAME]
	write_names.append_array(_artifact_name_list)
	for name_value in write_names:
		var artifact_name := String(name_value)
		var bytes := _decode_bytes(
			String(_encoded_payloads[artifact_name]))
		var write_result := _write_new_file(
			destination.path_join(artifact_name), bytes)
		if not bool(write_result.get("ok", false)):
			_remove_materialized_tree(destination)
			return write_result
	return {
		"ok": true,
		"bundle_path": destination,
		"parent_path": parent,
		"run_id": run_id,
		"artifact_count": _artifact_name_list.size(),
		"checksums_sha256": _checksums_sha256,
		"manifest_sha256": sha256(MANIFEST_NAME),
	}
# gdlint: enable=max-returns


func read_json_object(artifact_name: String) -> Dictionary:
	var payload_result := _stored_payload(artifact_name, true, "json")
	if not bool(payload_result.get("ok", false)):
		return FrozenValueScript.snapshot(payload_result)
	var parsed := _parse_json_object_bytes(
		payload_result["bytes"], artifact_name)
	return FrozenValueScript.snapshot(parsed)


func read_jsonl(artifact_name: String, required: bool) -> Dictionary:
	if not _encoded_payloads.has(artifact_name):
		if not required:
			return FrozenValueScript.snapshot({
				"ok": true,
				"records": [],
				"record_count": 0,
			})
		return FrozenValueScript.snapshot(_failure(
			FailureCodesScript.ARTIFACT_MISSING,
			"Required snapshot stream is not present in the authenticated index.",
			"/%s" % artifact_name,
			{"artifact": artifact_name}))
	var payload_result := _stored_payload(artifact_name, true, "jsonl")
	if not bool(payload_result.get("ok", false)):
		return FrozenValueScript.snapshot(payload_result)
	var parsed := _parse_jsonl_bytes(
		payload_result["bytes"], artifact_name)
	if not bool(parsed.get("ok", false)):
		return FrozenValueScript.snapshot(parsed)
	var entry: Dictionary = _artifact_metadata[artifact_name]
	var expected_records := _exact_nonnegative_integer(
		entry.get("records"))
	if expected_records < 0 \
			or int(parsed["record_count"]) != expected_records:
		return FrozenValueScript.snapshot(_failure(
			FailureCodesScript.LINE_COUNT_MISMATCH,
			"Parsed snapshot record count does not match checksums.json.",
			"/checksums.json/artifacts/%s/records" % artifact_name,
			{
				"artifact": artifact_name,
				"expected_records": expected_records,
				"actual_records": parsed["record_count"],
			}))
	return FrozenValueScript.snapshot(parsed)


func artifact_names() -> Array:
	return _artifact_name_list


func sha256(artifact_name: String) -> String:
	if artifact_name == CHECKSUMS_NAME:
		return _checksums_sha256
	if not _artifact_metadata.has(artifact_name):
		return ""
	return String(_artifact_metadata[artifact_name].get("sha256", ""))


func bytes_count(artifact_name: String) -> int:
	if artifact_name == CHECKSUMS_NAME:
		return _checksums_bytes
	if not _artifact_metadata.has(artifact_name):
		return -1
	return _exact_nonnegative_integer(
		_artifact_metadata[artifact_name].get("bytes"))


func checksums() -> Dictionary:
	return _captured_checksums


func publication_witness() -> Dictionary:
	return _captured_witness


func _stored_payload(
		artifact_name: String,
		required: bool,
		expected_kind: String) -> Dictionary:
	if not _encoded_payloads.has(artifact_name):
		if required:
			return _failure(
				FailureCodesScript.ARTIFACT_MISSING,
				"Required artifact is absent from the authenticated snapshot.",
				"/%s" % artifact_name,
				{"artifact": artifact_name})
		return {"ok": true, "bytes": PackedByteArray()}
	if artifact_name == CHECKSUMS_NAME:
		if expected_kind != "json":
			return _failure(
				FailureCodesScript.EVIDENCE_INVALID,
				"checksums.json is a JSON object, not the requested artifact kind.",
				"/checksums.json")
	else:
		var actual_kind := String(
			_artifact_metadata[artifact_name].get("kind", ""))
		if actual_kind != expected_kind:
			return _failure(
				FailureCodesScript.EVIDENCE_INVALID,
				"Snapshot artifact kind does not match the requested parser.",
				"/checksums.json/artifacts/%s/kind" % artifact_name,
				{
					"artifact": artifact_name,
					"expected_kind": expected_kind,
					"actual_kind": actual_kind,
				})
	return {
		"ok": true,
		"bytes": _decode_bytes(String(_encoded_payloads[artifact_name])),
	}


static func _validated_attestation_witness(
		validation: Dictionary) -> Dictionary:
	if not bool(validation.get("ok", false)) \
			or not bool(validation.get("can_finalize", false)) \
			or bool(validation.get("is_partial", true)):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"Snapshot capture requires a completed successful bundle validation.",
			"/validation")
	var stats_value: Variant = validation.get("stats")
	if typeof(stats_value) != TYPE_DICTIONARY:
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"Validation has no machine-readable statistics.",
			"/validation/stats")
	var attestation_value: Variant = (stats_value as Dictionary).get(
		"publication_attestation")
	if typeof(attestation_value) != TYPE_DICTIONARY:
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
			"Validation has no publication-attestation witness.",
			"/validation/stats/publication_attestation")
	return _validated_attestation(attestation_value)


static func _validated_attestation(
		attestation: Dictionary) -> Dictionary:
	if not bool(attestation.get("ok", false)):
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
			"Validation did not complete a required publication attestation.",
			"/validation/stats/publication_attestation")
	var trust_mode := String(attestation.get("trust_mode", ""))
	if trust_mode not in ["production", "test"]:
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"Publication witness has an unknown trust mode.",
			"/validation/stats/publication_attestation/trust_mode")
	if String(attestation.get("algorithm", "")) != ATTESTATION_ALGORITHM:
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
			"Publication witness has an unsupported authentication algorithm.",
			"/validation/stats/publication_attestation/algorithm")
	var checksums_sha256 := String(attestation.get(
		"checksums_sha256", ""))
	var manifest_sha256 := String(attestation.get(
		"manifest_sha256", ""))
	var receipt_sha256 := String(attestation.get(
		"receipt_sha256", ""))
	var key_id := String(attestation.get("key_id", ""))
	var artifact_count := _exact_nonnegative_integer(
		attestation.get("artifact_count"))
	if not _is_sha256(checksums_sha256) \
			or not _is_sha256(manifest_sha256) \
			or not _is_sha256(receipt_sha256) \
			or not _is_sha256(key_id) \
			or artifact_count < 1:
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
			"Publication witness is missing an authenticated envelope field.",
			"/validation/stats/publication_attestation")
	var run_id := String(attestation.get("run_id", ""))
	if not _is_safe_run_id(run_id):
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
			"Publication witness has no safe authenticated run identity.",
			"/validation/stats/publication_attestation/run_id")
	return {
		"ok": true,
		"witness": {
			"ok": true,
			"algorithm": ATTESTATION_ALGORITHM,
			"trust_mode": trust_mode,
			"receipt_sha256": receipt_sha256,
			"key_id": key_id,
			"run_id": run_id,
			"checksums_sha256": checksums_sha256,
			"manifest_sha256": manifest_sha256,
			"artifact_count": artifact_count,
			"attested_utc": String(attestation.get("attested_utc", "")),
		},
	}


static func _reverify_supplied_attestation(
		bundle_path: String,
		supplied: Dictionary) -> Dictionary:
	var trust_mode := String(supplied.get("trust_mode", ""))
	var verification: Dictionary
	if trust_mode == "production":
		verification = PublicationAttestationScript.verify_production(
			bundle_path)
	elif trust_mode == "test":
		var receipt_path := _normalized_absolute(String(
			supplied.get("receipt_path", "")))
		if receipt_path.is_empty() \
				or receipt_path.get_base_dir().get_file() != "receipts":
			return _failure(
				FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
				"Test publication witness has no derivable receipt trust root.",
				"/publication_attestation/receipt_path")
		var trust_root := receipt_path.get_base_dir().get_base_dir()
		verification = (
			PublicationAttestationScript.verify_with_test_trust_root(
				bundle_path, trust_root))
	else:
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"Publication witness has an unknown trust mode.",
			"/publication_attestation/trust_mode")
	if not bool(verification.get("ok", false)):
		return _failure(
			String(verification.get(
				"failure_code",
				verification.get(
					"code",
					FailureCodesScript.PUBLICATION_RECEIPT_INVALID))),
			"Independent publication re-verification failed.",
			"/publication_attestation",
			{"verification": _safe_verification_failure(verification)})
	return {
		"ok": true,
		"verification": verification,
	}


static func _safe_verification_failure(
		verification: Dictionary) -> Dictionary:
	# Never propagate accidental key material from a lower layer.  The current
	# verifier does not return secrets, but an allowlist keeps this boundary
	# safe if its internal diagnostics grow later.
	return {
		"ok": bool(verification.get("ok", false)),
		"failure_code": String(verification.get(
			"failure_code", verification.get("code", ""))),
		"message": String(verification.get("message", "")),
		"trust_mode": String(verification.get("trust_mode", "")),
		"receipt_path": String(verification.get("receipt_path", "")),
	}


static func _validate_checksum_index(
		checksums: Dictionary,
		witness: Dictionary) -> Dictionary:
	var expected_keys := [
		"schema",
		"run_id",
		"algorithm",
		"artifact_count",
		"artifacts",
	]
	var actual_keys := checksums.keys()
	actual_keys.sort()
	expected_keys.sort()
	if actual_keys != expected_keys \
			or String(checksums.get("schema", "")) != CHECKSUMS_SCHEMA \
			or String(checksums.get("algorithm", "")) != "sha256":
		return _failure(
			FailureCodesScript.SCHEMA_INVALID,
			"Captured checksums.json is not the strict v1 index shape.",
			"/checksums.json")
	if String(checksums.get("run_id", "")) != String(witness["run_id"]):
		return _failure(
			FailureCodesScript.RUN_ID_MISMATCH,
			"Captured index run_id does not match the authenticated receipt.",
			"/checksums.json/run_id")
	var artifacts_value: Variant = checksums.get("artifacts")
	if typeof(artifacts_value) != TYPE_DICTIONARY:
		return _failure(
			FailureCodesScript.SCHEMA_INVALID,
			"Captured checksums.json artifacts field is not an object.",
			"/checksums.json/artifacts")
	var artifacts: Dictionary = artifacts_value
	var indexed_count := _exact_nonnegative_integer(
		checksums.get("artifact_count"))
	if indexed_count < 1 \
			or indexed_count != artifacts.size() \
			or indexed_count != int(witness["artifact_count"]):
		return _failure(
			FailureCodesScript.LINE_COUNT_MISMATCH,
			"Captured artifact count does not match both index and authenticated envelope.",
			"/checksums.json/artifact_count",
			{
				"indexed_count": indexed_count,
				"map_count": artifacts.size(),
				"authenticated_count": witness["artifact_count"],
			})
	if not artifacts.has(MANIFEST_NAME):
		return _failure(
			FailureCodesScript.ARTIFACT_MISSING,
			"Captured authenticated index does not seal manifest.json.",
			"/checksums.json/artifacts/manifest.json")
	for name_value in artifacts:
		var artifact_name := String(name_value)
		if not _is_safe_artifact_name(artifact_name) \
				or artifact_name == CHECKSUMS_NAME:
			return _failure(
				FailureCodesScript.ARTIFACT_UNDECLARED,
				"Captured index contains an unsafe artifact name.",
				"/checksums.json/artifacts/%s" % artifact_name)
		var entry_value: Variant = artifacts[name_value]
		if typeof(entry_value) != TYPE_DICTIONARY:
			return _failure(
				FailureCodesScript.SCHEMA_INVALID,
				"Captured artifact index entry is not an object.",
				"/checksums.json/artifacts/%s" % artifact_name)
		var entry: Dictionary = entry_value
		var entry_keys := entry.keys()
		entry_keys.sort()
		var required_entry_keys := ["bytes", "kind", "records", "sha256"]
		required_entry_keys.sort()
		if entry_keys != required_entry_keys \
				or not _is_sha256(String(entry.get("sha256", ""))) \
				or _exact_nonnegative_integer(entry.get("bytes")) < 0 \
				or String(entry.get("kind", "")) \
					not in ["json", "jsonl", "opaque"]:
			return _failure(
				FailureCodesScript.SCHEMA_INVALID,
				"Captured artifact index entry is not strict checksums v1.",
				"/checksums.json/artifacts/%s" % artifact_name)
		var kind := String(entry.get("kind", ""))
		var records: Variant = entry.get("records")
		if kind == "jsonl":
			if _exact_nonnegative_integer(records) < 0:
				return _failure(
					FailureCodesScript.SCHEMA_INVALID,
					"JSONL index entries require an exact nonnegative record count.",
					"/checksums.json/artifacts/%s/records" % artifact_name)
		elif records != null:
			return _failure(
				FailureCodesScript.SCHEMA_INVALID,
				"Non-JSONL index entries require records=null.",
				"/checksums.json/artifacts/%s/records" % artifact_name)
	return {"ok": true}


static func _validate_directory_inventory(
		bundle_path: String,
		indexed_names: Array) -> Dictionary:
	var allowed: Dictionary = {CHECKSUMS_NAME: true}
	for name_value in indexed_names:
		allowed[String(name_value)] = true
	var directory := DirAccess.open(bundle_path)
	if directory == null:
		return _failure(
			FailureCodesScript.ARTIFACT_MISSING,
			"Snapshot source directory became unavailable.",
			"/")
	# Godot hides dot-prefixed entries unless this is enabled. A completed
	# bundle is a closed flat set, so hidden files and directories must be
	# judged against the authenticated index exactly like visible entries.
	directory.include_hidden = true
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if directory.current_is_dir() or not allowed.has(name):
			directory.list_dir_end()
			return _failure(
				FailureCodesScript.ARTIFACT_UNDECLARED,
				"Completed bundle contains an entry outside the authenticated artifact index.",
				"/%s" % name,
				{"artifact": name})
		name = directory.get_next()
	directory.list_dir_end()
	return {"ok": true}


static func _read_file_once(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure(
			FailureCodesScript.ARTIFACT_MISSING,
			"Snapshot artifact could not be opened.",
			"/%s" % path.get_file(),
			{"open_error": error_string(FileAccess.get_open_error())})
	var expected_length := file.get_length()
	if expected_length < 0:
		file.close()
		return _failure(
			FailureCodesScript.BYTE_COUNT_MISMATCH,
			"Snapshot artifact reported an invalid byte length.",
			"/%s" % path.get_file())
	var bytes := file.get_buffer(expected_length)
	var read_error := file.get_error()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF:
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"Snapshot artifact content read failed.",
			"/%s" % path.get_file(),
			{"read_error": error_string(read_error)})
	if bytes.size() != expected_length:
		return _failure(
			FailureCodesScript.BYTE_COUNT_MISMATCH,
			"Snapshot artifact changed or truncated during its sole content read.",
			"/%s" % path.get_file(),
			{
				"opened_bytes": expected_length,
				"captured_bytes": bytes.size(),
			})
	return {
		"ok": true,
		"bytes": bytes,
	}


static func _directory_is_empty(path: String) -> Dictionary:
	var directory := DirAccess.open(path)
	if directory == null:
		return _failure(
			FailureCodesScript.ARTIFACT_MISSING,
			"Snapshot materialization parent could not be opened.",
			"/materialization/parent")
	directory.include_hidden = true
	directory.list_dir_begin()
	var first_entry := directory.get_next()
	directory.list_dir_end()
	return {
		"ok": true,
		"empty": first_entry.is_empty(),
	}


static func _write_new_file(
		path: String,
		bytes: PackedByteArray) -> Dictionary:
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		return _failure(
			FailureCodesScript.RUN_RESERVATION_COLLISION,
			"Snapshot materialization refuses to overwrite an existing entry.",
			"/materialization/%s" % path.get_file())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _failure(
			FailureCodesScript.TRACE_WRITE_FAILED,
			"Snapshot artifact could not be materialized.",
			"/materialization/%s" % path.get_file(),
			{"open_error": error_string(FileAccess.get_open_error())})
	file.store_buffer(bytes)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return _failure(
			FailureCodesScript.TRACE_WRITE_FAILED,
			"Snapshot artifact materialization failed.",
			"/materialization/%s" % path.get_file(),
			{"write_error": error_string(write_error)})
	if FileAccess.get_file_as_bytes(path) != bytes:
		return _failure(
			FailureCodesScript.CHECKSUM_MISMATCH,
			"Materialized artifact did not round-trip exact snapshot bytes.",
			"/materialization/%s" % path.get_file())
	return {"ok": true}


func _remove_materialized_tree(path: String) -> void:
	# Only remove the flat artifact names this instance attempted to create.  An
	# unexpected directory or foreign filename is preserved rather than
	# recursively deleting data that this method does not own.
	var owned_names: Array = [CHECKSUMS_NAME]
	owned_names.append_array(_artifact_name_list)
	for name_value in owned_names:
		var child := path.path_join(String(name_value))
		if FileAccess.file_exists(child):
			DirAccess.remove_absolute(child)
	DirAccess.remove_absolute(path)


static func _parse_json_object_bytes(
		bytes: PackedByteArray,
		artifact_name: String) -> Dictionary:
	var parser := JSON.new()
	var parse_error := parser.parse(bytes.get_string_from_utf8())
	if parse_error != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return _failure(
			FailureCodesScript.JSON_PARSE_FAILED,
			"Snapshot JSON object parse failed.",
			"/%s" % artifact_name,
			{
				"line": parser.get_error_line(),
				"parse_message": parser.get_error_message(),
			})
	return {
		"ok": true,
		"value": parser.data,
	}


static func _parse_jsonl_bytes(
		bytes: PackedByteArray,
		artifact_name: String) -> Dictionary:
	var text := bytes.get_string_from_utf8()
	var lines: Array[String] = []
	if not text.is_empty():
		for line_value in text.split("\n", true):
			lines.append(String(line_value))
		if text.ends_with("\n"):
			lines.resize(lines.size() - 1)
	var records: Array = []
	for line_index in lines.size():
		var line := lines[line_index]
		if line.ends_with("\r"):
			line = line.left(line.length() - 1)
		if line.is_empty():
			return _failure(
				FailureCodesScript.JSON_PARSE_FAILED,
				"Snapshot JSONL contains an empty interior record.",
				"/%s/%d" % [artifact_name, line_index])
		var parser := JSON.new()
		var parse_error := parser.parse(line)
		if parse_error != OK or typeof(parser.data) != TYPE_DICTIONARY:
			return _failure(
				FailureCodesScript.JSON_PARSE_FAILED,
				"Snapshot JSONL record parse failed.",
				"/%s/%d" % [artifact_name, line_index],
				{"parse_message": parser.get_error_message()})
		records.append(parser.data)
	return {
		"ok": true,
		"records": records,
		"record_count": records.size(),
	}


static func _encode_bytes(bytes: PackedByteArray) -> String:
	# Godot's Marshalls helper reports an engine error for an empty input even
	# though an empty artifact is valid and checksummed. Reserve the empty
	# string as the unambiguous encoding of a zero-byte payload.
	return "" if bytes.is_empty() else Marshalls.raw_to_base64(bytes)


static func _decode_bytes(encoded: String) -> PackedByteArray:
	return PackedByteArray() \
		if encoded.is_empty() \
		else Marshalls.base64_to_raw(encoded)


static func _sha256_bytes(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	# HashingContext rejects update() with a zero-length buffer even though
	# SHA-256 has a well-defined empty-message digest. Finalizing a newly
	# started context produces that digest without an engine error.
	if not bytes.is_empty() and context.update(bytes) != OK:
		context.finish()
		return ""
	return "sha256:%s" % context.finish().hex_encode()


static func _exact_nonnegative_integer(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return int(value) if int(value) >= 0 else -1
	if typeof(value) == TYPE_FLOAT:
		var number := float(value)
		if is_finite(number) and number >= 0.0 and number == floor(number):
			return int(number)
	return -1


static func _is_safe_run_id(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9][A-Za-z0-9._-]{0,159}$")
	return regex.search(value) != null


static func _is_safe_artifact_name(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9][A-Za-z0-9._-]*$")
	return regex.search(value) != null


static func _is_sha256(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^sha256:[a-f0-9]{64}$")
	return regex.search(value) != null


static func _normalized_absolute(path: String) -> String:
	var value := path.strip_edges().replace("\\", "/")
	if value.is_empty():
		return ""
	if value.begins_with("res://") or value.begins_with("user://"):
		value = ProjectSettings.globalize_path(value).replace("\\", "/")
	value = value.simplify_path()
	var windows_absolute := RegEx.new()
	windows_absolute.compile("^[A-Za-z]:/")
	if not value.begins_with("/") and windows_absolute.search(value) == null:
		return ""
	return value.trim_suffix("/")


static func _is_descendant(candidate: String, parent: String) -> bool:
	var child_identity := candidate.trim_suffix("/").to_lower()
	var parent_identity := parent.trim_suffix("/").to_lower()
	return child_identity.begins_with("%s/" % parent_identity)


static func _failure(
		failure_code: String,
		message: String,
		path: String,
		detail: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"code": failure_code,
		"failure_code": failure_code,
		"message": message,
		"path": path,
		"detail": detail,
	}
