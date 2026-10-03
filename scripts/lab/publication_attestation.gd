class_name LabPublicationAttestation
extends RefCounted

## Detached publication receipts close the integrity gap left by an unkeyed
## checksums.json file. The HMAC key and receipt are stored outside both the
## repository and the run bundle, so a writer restricted to the bundle/output
## store cannot replace all bundle bytes and manufacture matching provenance.
##
## Trust boundary:
## - production signing always resolves %LOCALAPPDATA%/SporeSpore/LabTrust/v1;
## - production callers cannot inject a key or alternate trust root;
## - test-root entry points are explicit, require a root below OS temp, and
##   return trust_mode="test" so integration can make the run non-promotable;
## - keys are raw, exactly 32 bytes, and are never returned or logged;
## - receipts are append-only and named by SHA-256(run_id), not by run_id.
##
## This protects against a bundle writer that cannot write the trust store. It
## does not protect against an account/admin that can read the HMAC key or alter
## this verifier.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FailureCodesScript := preload("res://scripts/lab/failure_codes.gd")
const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")

const RECEIPT_SCHEMA := "sporespore.lab.publication_attestation.v1"
const RECEIPT_DOMAIN := "sporespore.lab.publication_attestation.v1"
const ALGORITHM := "hmac-sha256"
const ACTIVE_KEY_SCHEMA := "sporespore.lab_attestation.active_key.v1"
const ACTIVE_KEY_FILE := "active_key.json"
const RECEIPT_SCHEMA_PATH := \
	"res://data/lab/schemas/publication_attestation_v1.schema.json"
const CHECKSUMS_SCHEMA_PATH := \
	"res://data/lab/schemas/checksums_v1.schema.json"
const MANIFEST_SCHEMA_PATH := \
	"res://data/lab/schemas/manifest_v1.schema.json"
const KEY_BYTES := 32
const CHUNK_BYTES := 65536


static func production_trust_root() -> String:
	var local_app_data := OS.get_environment("LOCALAPPDATA").strip_edges()
	if local_app_data.is_empty():
		return ""
	return _normalized_absolute(
		local_app_data.path_join("SporeSpore").path_join("LabTrust").path_join("v1"))


static func attest_production(bundle_path: String) -> Dictionary:
	var trust_root := production_trust_root()
	if trust_root.is_empty():
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"LOCALAPPDATA is unavailable; the fixed production trust root cannot be resolved.")
	return _attest(bundle_path, trust_root, "", "production")


static func verify_production(bundle_path: String) -> Dictionary:
	var trust_root := production_trust_root()
	if trust_root.is_empty():
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"LOCALAPPDATA is unavailable; the fixed production trust root cannot be resolved.")
	return _verify(bundle_path, trust_root, "production")


static func attest_with_test_trust_root(
		bundle_path: String,
		test_trust_root: String,
		attested_utc: String = "") -> Dictionary:
	var root_result := _validate_test_trust_root(test_trust_root)
	if not root_result["ok"]:
		return root_result
	return _attest(
		bundle_path,
		String(root_result["trust_root"]),
		attested_utc,
		"test")


static func verify_with_test_trust_root(
		bundle_path: String,
		test_trust_root: String) -> Dictionary:
	var root_result := _validate_test_trust_root(test_trust_root)
	if not root_result["ok"]:
		return root_result
	return _verify(bundle_path, String(root_result["trust_root"]), "test")


static func receipt_path_for_run_id(trust_root: String, run_id: String) -> String:
	if not _is_safe_run_id(run_id):
		return ""
	var normalized_root := _normalized_absolute(trust_root)
	if normalized_root.is_empty():
		return ""
	return normalized_root.path_join("receipts").path_join(
		"%s.json" % run_id.sha256_text())


## Test-only primitive for the published RFC 4231 vector. Production receipt
## entry points still enforce a 32-byte key before this primitive is reached.
static func hmac_sha256_hex_for_test(
		key: PackedByteArray,
		message: PackedByteArray) -> String:
	var result := _hmac_sha256(key, message)
	return String(result.get("hex", "")) if result["ok"] else ""


## Exposed only so the regression test can pin the comparison algorithm. Tag
## verification always calls this helper after strict receipt schema checking.
static func constant_time_equal_for_test(left: String, right: String) -> bool:
	return _constant_time_equal(left, right)


static func _attest(
		bundle_path: String,
		trust_root: String,
		attested_utc: String,
		trust_mode: String) -> Dictionary:
	var paths := _validate_nonoverlapping_paths(bundle_path, trust_root)
	if not paths["ok"]:
		return paths
	var bundle_result := _inspect_bundle(String(paths["bundle_path"]))
	if not bundle_result["ok"]:
		return bundle_result
	var key_reference := _load_active_key_reference(String(paths["trust_root"]))
	if not key_reference["ok"]:
		return key_reference

	var timestamp := attested_utc.strip_edges()
	if timestamp.is_empty():
		timestamp = _utc_now()
	var envelope := _unsigned_envelope(
		String(key_reference["key_id"]),
		bundle_result,
		timestamp)
	var envelope_bytes := CanonicalJsonScript.encode(envelope)
	var key_result := _load_key_by_id(
		String(paths["trust_root"]),
		String(key_reference["key_id"]))
	if not key_result["ok"]:
		return key_result
	var key := _take_loaded_key(key_result)
	var hmac_result := _hmac_sha256(
		key,
		envelope_bytes)
	# Packed arrays cross GDScript call boundaries through Variant and can
	# become copy-on-write values. Wipe the sole owning local in this scope
	# directly; a helper call could zero only a detached copy.
	key.fill(0)
	key.resize(0)
	if not hmac_result["ok"]:
		return hmac_result
	var receipt: Dictionary = envelope.duplicate(true)
	receipt["tag"] = "%s:%s" % [ALGORITHM, hmac_result["hex"]]
	var schema_result := SchemaValidatorScript.validate_file(
		RECEIPT_SCHEMA_PATH,
		receipt)
	if not schema_result["ok"]:
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
			"Generated publication receipt failed its owned schema.",
			{"errors": schema_result["errors"]})

	var receipt_path := receipt_path_for_run_id(
		String(paths["trust_root"]),
		String(bundle_result["run_id"]))
	var write_result := _write_receipt_new(receipt_path, receipt)
	if not write_result["ok"]:
		return write_result
	# Re-open both independently mutable sides after installation. A bundle
	# writer racing publication can cause a fail-closed denial, but cannot make
	# this function report success for bytes the installed receipt does not
	# authenticate.
	return _verify(
		String(paths["bundle_path"]),
		String(paths["trust_root"]),
		trust_mode)


static func _verify(
		bundle_path: String,
		trust_root: String,
		trust_mode: String) -> Dictionary:
	var paths := _validate_nonoverlapping_paths(bundle_path, trust_root)
	if not paths["ok"]:
		return paths
	var bundle_result := _inspect_bundle(String(paths["bundle_path"]))
	if not bundle_result["ok"]:
		return bundle_result
	var receipt_path := receipt_path_for_run_id(
		String(paths["trust_root"]),
		String(bundle_result["run_id"]))
	if not FileAccess.file_exists(receipt_path):
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_MISSING,
			"No detached publication receipt exists for this run.",
			{"receipt_path": receipt_path})
	var receipt_result := _read_json_object(receipt_path)
	if not receipt_result["ok"]:
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
			"Detached publication receipt is not valid JSON.",
			{"receipt_path": receipt_path})
	var receipt: Dictionary = receipt_result["value"]
	var schema_result := SchemaValidatorScript.validate_file(
		RECEIPT_SCHEMA_PATH,
		receipt)
	if not schema_result["ok"]:
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
			"Detached publication receipt failed its owned schema.",
			{
				"receipt_path": receipt_path,
				"errors": schema_result["errors"],
			})
	var canonical_receipt_bytes := CanonicalJsonScript.stringify(receipt) + "\n"
	if not _constant_time_equal(
			FileAccess.get_file_as_string(receipt_path),
			canonical_receipt_bytes):
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
			"Detached receipt bytes are not the one canonical encoding.",
			{"receipt_path": receipt_path})
	var expected_envelope := _unsigned_envelope(
		String(receipt["key_id"]),
		bundle_result,
		String(receipt["attested_utc"]))
	var recorded_envelope: Dictionary = receipt.duplicate(true)
	recorded_envelope.erase("tag")
	var recorded_envelope_text := CanonicalJsonScript.stringify(
		recorded_envelope)
	if not _constant_time_equal(
			recorded_envelope_text,
			CanonicalJsonScript.stringify(expected_envelope)):
		return _failure(
			FailureCodesScript.PUBLICATION_ENVELOPE_MISMATCH,
			"Receipt identity does not match the exact current bundle bytes.",
			{"receipt_path": receipt_path})
	var key_result := _load_key_by_id(
		String(paths["trust_root"]),
		String(receipt["key_id"]))
	if not key_result["ok"]:
		return key_result
	var key := _take_loaded_key(key_result)
	var hmac_result := _hmac_sha256(
		key,
		recorded_envelope_text.to_utf8_buffer())
	# See the copy-on-write note in _attest().
	key.fill(0)
	key.resize(0)
	if not hmac_result["ok"]:
		return hmac_result
	var expected_tag := "%s:%s" % [ALGORITHM, hmac_result["hex"]]
	if not _constant_time_equal(String(receipt["tag"]), expected_tag):
		return _failure(
			FailureCodesScript.PUBLICATION_TAG_MISMATCH,
			"Detached publication receipt authentication failed.",
			{"receipt_path": receipt_path})
	return {
		"ok": true,
		"code": "",
		"failure_code": "",
		"algorithm": ALGORITHM,
		"trust_mode": trust_mode,
		"receipt_path": receipt_path,
		"receipt_sha256": _sha256_file(receipt_path),
		"key_id": String(receipt["key_id"]),
		"run_id": String(bundle_result["run_id"]),
		"checksums_sha256": String(receipt["checksums_sha256"]),
		"manifest_sha256": String(receipt["manifest_sha256"]),
		"artifact_count": int(receipt["artifact_count"]),
		"attested_utc": String(receipt["attested_utc"]),
	}


static func _unsigned_envelope(
		key_id: String,
		bundle: Dictionary,
		attested_utc: String) -> Dictionary:
	return {
		"schema": RECEIPT_SCHEMA,
		"domain": RECEIPT_DOMAIN,
		"algorithm": ALGORITHM,
		"key_id": key_id,
		"run_id": String(bundle["run_id"]),
		"checksums_sha256": String(bundle["checksums_sha256"]),
		"manifest_sha256": String(bundle["manifest_sha256"]),
		"artifact_count": int(bundle["artifact_count"]),
		"attested_utc": attested_utc,
	}


static func _inspect_bundle(bundle_path: String) -> Dictionary:
	if not DirAccess.dir_exists_absolute(bundle_path):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"Publication target is not an existing bundle directory.")
	var checksums_path := bundle_path.path_join("checksums.json")
	var manifest_path := bundle_path.path_join("manifest.json")
	var checksums_result := _read_json_object(checksums_path)
	var manifest_result := _read_json_object(manifest_path)
	if not checksums_result["ok"] or not manifest_result["ok"]:
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"Publication requires readable checksums.json and manifest.json.")
	var checksums: Dictionary = checksums_result["value"]
	var manifest: Dictionary = manifest_result["value"]
	var checksums_schema := SchemaValidatorScript.validate_file(
		CHECKSUMS_SCHEMA_PATH,
		checksums)
	var manifest_schema := SchemaValidatorScript.validate_file(
		MANIFEST_SCHEMA_PATH,
		manifest)
	if not checksums_schema["ok"] or not manifest_schema["ok"]:
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"Publication target failed an owned bundle-index schema.",
			{
				"checksums_errors": checksums_schema["errors"],
				"manifest_errors": manifest_schema["errors"],
			})
	var run_id := String(checksums.get("run_id", ""))
	if (
		not _is_safe_run_id(run_id)
		or run_id != String(manifest.get("run_id", ""))
	):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"checksums.json and manifest.json do not identify one safe run_id.")
	if String(manifest.get("status", "")) != "COMPLETE":
		return _failure(
			FailureCodesScript.MANIFEST_NOT_COMPLETE,
			"Only COMPLETE bundles can receive a publication attestation.")
	var artifacts: Dictionary = checksums.get("artifacts", {})
	var artifact_count := _exact_nonnegative_integer(
		checksums.get("artifact_count"))
	if artifact_count < 1 or artifact_count != artifacts.size():
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"checksums.json artifact_count does not match its artifact map.")
	var seal_result := _verify_checksum_entries(bundle_path, artifacts)
	if not seal_result["ok"]:
		return seal_result
	var manifest_sha256 := _sha256_file(manifest_path)
	if (
		not artifacts.has("manifest.json")
		or String(artifacts["manifest.json"].get("sha256", ""))
			!= manifest_sha256
	):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"checksums.json does not seal the exact manifest.json bytes.")
	return {
		"ok": true,
		"run_id": run_id,
		"checksums_sha256": _sha256_file(checksums_path),
		"manifest_sha256": manifest_sha256,
		"artifact_count": artifact_count,
	}


static func _verify_checksum_entries(
		bundle_path: String,
		artifacts: Dictionary) -> Dictionary:
	var names := artifacts.keys()
	names.sort()
	for name_value in names:
		var artifact_name := String(name_value)
		if not _is_safe_artifact_name(artifact_name) or artifact_name == "checksums.json":
			return _failure(
				FailureCodesScript.EVIDENCE_INVALID,
				"checksums.json contains an unsafe artifact name.")
		var path := bundle_path.path_join(artifact_name)
		if not FileAccess.file_exists(path):
			return _failure(
				FailureCodesScript.ARTIFACT_MISSING,
				"A checksummed publication artifact is missing.",
				{"artifact": artifact_name})
		var entry: Dictionary = artifacts[name_value]
		if String(entry.get("sha256", "")) != _sha256_file(path):
			return _failure(
				FailureCodesScript.CHECKSUM_MISMATCH,
				"A publication artifact does not match checksums.json.",
				{"artifact": artifact_name})
		if _exact_nonnegative_integer(entry.get("bytes")) != _file_size(path):
			return _failure(
				FailureCodesScript.BYTE_COUNT_MISMATCH,
				"A publication artifact byte count does not match checksums.json.",
				{"artifact": artifact_name})
		if String(entry.get("kind", "")) == "jsonl":
			var records := _exact_nonnegative_integer(entry.get("records"))
			if records < 0 or records != _count_jsonl_records(path):
				return _failure(
					FailureCodesScript.LINE_COUNT_MISMATCH,
					"A publication JSONL record count does not match checksums.json.",
					{"artifact": artifact_name})
	return {"ok": true}


static func _load_active_key_reference(trust_root: String) -> Dictionary:
	var pointer_path := trust_root.path_join(ACTIVE_KEY_FILE)
	if not FileAccess.file_exists(pointer_path):
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_MISSING,
			"The attestation trust root has no active_key.json pointer.")
	var pointer_result := _read_json_object(pointer_path)
	if not pointer_result["ok"]:
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_INVALID,
			"active_key.json is not valid JSON.")
	var pointer: Dictionary = pointer_result["value"]
	var expected_fields: Array[String] = [
		"schema_version",
		"algorithm",
		"key_id",
		"key_file",
	]
	if pointer.size() != expected_fields.size():
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_INVALID,
			"active_key.json must contain exactly the initializer-owned fields.")
	for field in expected_fields:
		if not pointer.has(field):
			return _failure(
				FailureCodesScript.PUBLICATION_KEY_INVALID,
				"active_key.json is missing an initializer-owned field.")
	if (
		String(pointer["schema_version"]) != ACTIVE_KEY_SCHEMA
		or String(pointer["algorithm"]) != ALGORITHM
	):
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_INVALID,
			"active_key.json uses an unsupported schema or algorithm.")
	var key_id := String(pointer["key_id"])
	if not _is_sha256(key_id):
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_INVALID,
			"active_key.json key_id is not a SHA-256 identity.")
	var expected_file := "keys/%s.key" % key_id.trim_prefix("sha256:")
	if String(pointer["key_file"]) != expected_file:
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_INVALID,
			"active_key.json key_file does not match its key_id.")
	return {
		"ok": true,
		"key_id": key_id,
	}


static func _load_key_by_id(trust_root: String, key_id: String) -> Dictionary:
	if not _is_sha256(key_id):
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_INVALID,
			"Receipt key_id is not a SHA-256 identity.")
	var key_path := trust_root.path_join("keys").path_join(
		"%s.key" % key_id.trim_prefix("sha256:"))
	if not _is_descendant(key_path, trust_root):
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_INVALID,
			"Resolved key path escaped the trust root.")
	if not FileAccess.file_exists(key_path):
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_MISSING,
			"The receipt's keyed identity is not present in the trust root.")
	var file := FileAccess.open(key_path, FileAccess.READ)
	if file == null:
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_MISSING,
			"The receipt key file could not be opened.")
	if file.get_length() != KEY_BYTES:
		file.close()
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_INVALID,
			"Publication HMAC keys must be exactly 32 raw bytes.")
	var key := file.get_buffer(KEY_BYTES)
	file.close()
	if key.size() != KEY_BYTES:
		key.fill(0)
		key.resize(0)
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_INVALID,
			"Publication HMAC key read was truncated.")
	var observed_id := _sha256_bytes(key)
	if not _constant_time_equal(observed_id, key_id):
		key.fill(0)
		key.resize(0)
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_INVALID,
			"Publication HMAC key bytes do not match their key_id.")
	return {
		"ok": true,
		"key": key,
		"key_id": observed_id,
	}


static func _take_loaded_key(key_result: Dictionary) -> PackedByteArray:
	# Remove the secret-bearing value from the result container before the
	# caller starts work. This matters even on copy-on-write builds: wiping the
	# local array must not leave an unmodified shared reference in a Dictionary.
	var key: PackedByteArray = key_result.get("key", PackedByteArray())
	key_result["key"] = PackedByteArray()
	return key


static func _write_receipt_new(path: String, receipt: Dictionary) -> Dictionary:
	# Godot exposes atomic directory creation but no cross-platform
	# FileMode.CreateNew equivalent. Reserve a per-receipt directory first, then
	# install from a temp file owned by that reservation. On the production
	# Windows target rename cannot replace an existing destination. Every
	# compliant writer also rechecks the target before install; a process able
	# to bypass the protected trust-store ACL is outside this threat boundary.
	var parent := path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(parent)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_WRITE_FAILED,
			"Could not create the detached receipt directory.")
	if _path_entry_exists(path):
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_COLLISION,
			"A detached receipt already exists; publication receipts are append-only.",
			{"receipt_path": path})
	var reservation := "%s.attestation-lock" % path
	var reservation_error := DirAccess.make_dir_absolute(reservation)
	if reservation_error != OK:
		if _path_entry_exists(path):
			return _failure(
				FailureCodesScript.PUBLICATION_RECEIPT_COLLISION,
				"A detached receipt already exists; publication receipts are append-only.",
				{"receipt_path": path})
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_BUSY,
			"Another attester owns this receipt path, or a prior crash left its lock.",
			{"receipt_path": path})
	if _path_entry_exists(path):
		DirAccess.remove_absolute(reservation)
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_COLLISION,
			"A detached receipt already exists; publication receipts are append-only.",
			{"receipt_path": path})
	var temporary := reservation.path_join(
		"receipt-%d-%d.tmp" % [OS.get_process_id(), Time.get_ticks_usec()])
	var serialized := CanonicalJsonScript.stringify(receipt) + "\n"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		DirAccess.remove_absolute(reservation)
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_WRITE_FAILED,
			"Could not open the detached receipt temporary file.")
	file.store_string(serialized)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		DirAccess.remove_absolute(reservation)
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_WRITE_FAILED,
			"Could not flush the detached receipt temporary file.")
	if _path_entry_exists(path):
		DirAccess.remove_absolute(temporary)
		DirAccess.remove_absolute(reservation)
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_COLLISION,
			"A detached receipt already exists; publication receipts are append-only.",
			{"receipt_path": path})
	var rename_error := DirAccess.rename_absolute(temporary, path)
	if rename_error != OK:
		DirAccess.remove_absolute(temporary)
		DirAccess.remove_absolute(reservation)
		if _path_entry_exists(path):
			return _failure(
				FailureCodesScript.PUBLICATION_RECEIPT_COLLISION,
				"A detached receipt won the publication race.",
				{"receipt_path": path})
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_WRITE_FAILED,
			"Could not install the detached receipt.",
			{"error": error_string(rename_error)})
	var installed_matches := FileAccess.get_file_as_string(path) == serialized
	DirAccess.remove_absolute(reservation)
	if not installed_matches:
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_WRITE_FAILED,
			"Installed detached receipt bytes differ from the canonical payload.")
	return {"ok": true}


static func _hmac_sha256(
		key: PackedByteArray,
		message: PackedByteArray) -> Dictionary:
	var context := HMACContext.new()
	var start_error := context.start(HashingContext.HASH_SHA256, key)
	if start_error != OK:
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_INVALID,
			"HMAC-SHA-256 initialization failed.")
	var update_error := context.update(message)
	if update_error != OK:
		context.finish()
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
			"HMAC-SHA-256 message update failed.")
	var digest := context.finish()
	if digest.size() != 32:
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
			"HMAC-SHA-256 returned an invalid digest length.")
	return {
		"ok": true,
		"hex": digest.hex_encode(),
	}


static func _constant_time_equal(left: String, right: String) -> bool:
	var left_bytes := left.to_utf8_buffer()
	var right_bytes := right.to_utf8_buffer()
	var difference := left_bytes.size() ^ right_bytes.size()
	var length := maxi(left_bytes.size(), right_bytes.size())
	for index in length:
		var left_byte := int(left_bytes[index]) if index < left_bytes.size() else 0
		var right_byte := int(right_bytes[index]) if index < right_bytes.size() else 0
		difference = difference | (left_byte ^ right_byte)
	return difference == 0


static func _validate_test_trust_root(value: String) -> Dictionary:
	var trust_root := _normalized_absolute(value)
	var temp_root := _normalized_absolute(OS.get_temp_dir())
	if (
		trust_root.is_empty()
		or temp_root.is_empty()
		or trust_root == temp_root
		or not _is_descendant(trust_root, temp_root)
	):
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"Test trust roots must be strict descendants of OS.get_temp_dir().")
	return {
		"ok": true,
		"trust_root": trust_root,
		"trust_mode": "test",
	}


static func _validate_nonoverlapping_paths(
		bundle_path: String,
		trust_root: String) -> Dictionary:
	var bundle := _normalized_absolute(bundle_path)
	var trust := _normalized_absolute(trust_root)
	var project_root := _normalized_absolute(ProjectSettings.globalize_path("res://"))
	if bundle.is_empty() or trust.is_empty():
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"Bundle and trust-root paths must resolve to absolute paths.")
	if _paths_overlap(bundle, trust):
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"The detached trust root must not contain or be contained by the bundle.")
	if trust == project_root or _is_descendant(trust, project_root):
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"The detached trust root must remain outside the project repository.")
	return {
		"ok": true,
		"bundle_path": bundle,
		"trust_root": trust,
	}


static func _paths_overlap(left: String, right: String) -> bool:
	return (
		_path_identity(left) == _path_identity(right)
		or _is_descendant(left, right)
		or _is_descendant(right, left)
	)


static func _is_descendant(candidate: String, parent: String) -> bool:
	var candidate_identity := _path_identity(candidate)
	var parent_identity := _path_identity(parent).trim_suffix("/")
	return candidate_identity.begins_with("%s/" % parent_identity)


static func _path_identity(path: String) -> String:
	# Windows is the production platform and its path identity is
	# case-insensitive. Lower-casing on other platforms is conservative: it can
	# reject an ambiguous test layout, but cannot weaken path separation.
	return _normalized_absolute(path).trim_suffix("/").to_lower()


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


static func _read_json_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"ok": false}
	if typeof(parser.data) != TYPE_DICTIONARY:
		return {"ok": false}
	return {
		"ok": true,
		"value": parser.data,
	}


static func _path_entry_exists(path: String) -> bool:
	return (
		FileAccess.file_exists(path)
		or DirAccess.dir_exists_absolute(path)
	)


static func _sha256_bytes(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(bytes) != OK:
		context.finish()
		return ""
	return "sha256:%s" % context.finish().hex_encode()


static func _sha256_file(path: String) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	while file.get_position() < file.get_length():
		var remaining := file.get_length() - file.get_position()
		if context.update(file.get_buffer(mini(CHUNK_BYTES, remaining))) != OK:
			context.finish()
			return ""
	return "sha256:%s" % context.finish().hex_encode()


static func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_length() if file != null else -1


static func _count_jsonl_records(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var count := 0
	while file.get_position() < file.get_length():
		file.get_line()
		count += 1
	return count


static func _exact_nonnegative_integer(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return int(value) if int(value) >= 0 else -1
	if (
		typeof(value) == TYPE_FLOAT
		and is_finite(float(value))
		and float(value) >= 0.0
		and float(value) <= 9007199254740991.0
		and floor(float(value)) == float(value)
	):
		return int(value)
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


static func _utc_now() -> String:
	var timestamp := Time.get_datetime_string_from_system(true, false)
	return timestamp if timestamp.ends_with("Z") else "%sZ" % timestamp


static func _failure(
		failure_code: String,
		message: String,
		detail: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"code": failure_code,
		"failure_code": failure_code,
		"message": message,
		"detail": detail,
	}
