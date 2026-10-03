extends SceneTree

const AttestationScript := preload(
	"res://scripts/lab/publication_attestation.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FailureCodesScript := preload("res://scripts/lab/failure_codes.gd")
const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")

const HASH := \
	"sha256:0000000000000000000000000000000000000000000000000000000000000000"
const FIXED_TIME := "2026-07-19T18:00:00Z"

var _passed := 0
var _failed := 0
var _token := ""
var _temp_base := ""
var _user_base := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_token = "%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_temp_base = _normalize(
		OS.get_temp_dir().path_join("SporeSporeAttestationTests").path_join(_token))
	_user_base = _temp_base.path_join("bundles")
	DirAccess.make_dir_recursive_absolute(_temp_base)
	DirAccess.make_dir_recursive_absolute(_user_base)
	print("=== Lab detached publication attestation tests ===")
	_test_production_root_is_fixed()
	_test_failure_codes_are_registered()
	_test_rfc_4231_hmac_vector_and_constant_time_compare()
	_test_create_verify_exact_byte_mutation_and_collision()
	_test_key_pointer_and_key_length_are_strict()
	_test_missing_and_busy_receipts_fail_closed()
	_test_trust_root_path_separation()
	var initializer_root := _argument_value("--initializer-trust-root")
	if not initializer_root.is_empty():
		_test_real_initializer_compatibility(initializer_root)
	_remove_tree(_temp_base)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_production_root_is_fixed() -> void:
	print("- derives one production trust root from LOCALAPPDATA")
	var local_app_data := OS.get_environment("LOCALAPPDATA").strip_edges()
	var observed := AttestationScript.production_trust_root()
	if local_app_data.is_empty():
		_check(observed.is_empty(), "missing LOCALAPPDATA fails root resolution closed")
		return
	var expected := _normalize(
		local_app_data.path_join("SporeSpore").path_join("LabTrust").path_join("v1"))
	_check(observed == expected, "production trust root is fixed below LOCALAPPDATA")
	_check(
		not observed.to_lower().begins_with(
			_normalize(ProjectSettings.globalize_path("res://")).to_lower()),
		"production trust root is outside the repository")


func _test_failure_codes_are_registered() -> void:
	print("- appends every publication failure code to the stable registry")
	for code in [
		FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
		FailureCodesScript.PUBLICATION_KEY_MISSING,
		FailureCodesScript.PUBLICATION_KEY_INVALID,
		FailureCodesScript.PUBLICATION_RECEIPT_MISSING,
		FailureCodesScript.PUBLICATION_RECEIPT_COLLISION,
		FailureCodesScript.PUBLICATION_RECEIPT_BUSY,
		FailureCodesScript.PUBLICATION_RECEIPT_WRITE_FAILED,
		FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
		FailureCodesScript.PUBLICATION_ENVELOPE_MISMATCH,
		FailureCodesScript.PUBLICATION_TAG_MISMATCH,
	]:
		_check(
			FailureCodesScript.is_registered(String(code)),
			"failure registry contains %s" % String(code))


func _test_rfc_4231_hmac_vector_and_constant_time_compare() -> void:
	print("- pins HMAC-SHA-256 to the published RFC 4231 vector")
	var key := PackedByteArray()
	for _index in 20:
		key.append(0x0b)
	var observed := AttestationScript.hmac_sha256_hex_for_test(
		key,
		"Hi There".to_utf8_buffer())
	_check(
		observed
			== "b0344c61d8db38535ca8afceaf0bf12b"
				+ "881dc200c9833da726e9376c2e32cff7",
		"RFC 4231 test case 1 matches exactly")
	_check(
		AttestationScript.constant_time_equal_for_test(observed, observed),
		"constant-time comparison accepts identical tags")
	_check(
		not AttestationScript.constant_time_equal_for_test(
			observed,
			observed.left(observed.length() - 1) + "0"),
		"constant-time comparison rejects a one-nibble mutation")
	_check(
		not AttestationScript.constant_time_equal_for_test(observed, observed.left(12)),
		"constant-time comparison rejects a length mutation")


func _test_create_verify_exact_byte_mutation_and_collision() -> void:
	print("- creates one append-only detached receipt and authenticates exact bytes")
	var bundle_path := _user_base.path_join("bundle-primary")
	var run_id := "attestation-primary-%s" % _token
	_build_bundle(bundle_path, run_id)
	var trust_root := _temp_base.path_join("trust-primary")
	var key := _key_bytes(32, 17)
	var key_id := _install_key(trust_root, key)
	var attested := AttestationScript.attest_with_test_trust_root(
		bundle_path,
		trust_root,
		FIXED_TIME)
	_check(bool(attested["ok"]), "initializer-compatible test trust root can attest")
	if not attested["ok"]:
		printerr("    attestation failure: ", attested)
		return
	_check(attested["trust_mode"] == "test",
		"injected trust-root result is explicitly marked test/non-production")
	_check(attested["key_id"] == key_id,
		"receipt reports the SHA-256 identity of the exact 32-byte key")
	_check(not attested.has("key"), "public result never returns secret key bytes")
	var receipt_path := String(attested["receipt_path"])
	_check(
		receipt_path.get_file() == "%s.json" % run_id.sha256_text()
			and not receipt_path.get_file().contains(run_id),
		"receipt filename is SHA-256(run_id), not caller-controlled run_id text")
	var receipt_result := _read_object(receipt_path)
	_check(bool(receipt_result["ok"]), "detached receipt is readable JSON")
	if not receipt_result["ok"]:
		return
	var receipt: Dictionary = receipt_result["value"]
	var schema := SchemaValidatorScript.validate_file(
		"res://data/lab/schemas/publication_attestation_v1.schema.json",
		receipt)
	_check(bool(schema["ok"]), "detached receipt passes its owned strict schema")
	var receipt_with_extra: Dictionary = receipt.duplicate(true)
	receipt_with_extra["unsigned_but_ignored"] = true
	var extra_schema := SchemaValidatorScript.validate_file(
		"res://data/lab/schemas/publication_attestation_v1.schema.json",
		receipt_with_extra)
	_check(
		not extra_schema["ok"],
		"receipt schema rejects unsigned/unowned extension fields")
	_check(
		receipt["checksums_sha256"]
			== "sha256:%s"
				% FileAccess.get_sha256(bundle_path.path_join("checksums.json")),
		"envelope seals the exact checksums.json bytes")
	_check(
		receipt["manifest_sha256"]
			== "sha256:%s"
				% FileAccess.get_sha256(bundle_path.path_join("manifest.json")),
		"envelope separately seals the exact manifest.json bytes")
	var verified := AttestationScript.verify_with_test_trust_root(
		bundle_path,
		trust_root)
	_check(bool(verified["ok"]), "fresh detached receipt verifies")
	_check(
		verified.get("algorithm") == "hmac-sha256"
			and verified.get("checksums_sha256")
				== receipt["checksums_sha256"]
			and verified.get("manifest_sha256")
				== receipt["manifest_sha256"]
			and int(verified.get("artifact_count", -1))
				== int(receipt["artifact_count"]),
		"verification returns the authenticated envelope needed for read-once consumers")
	_check(verified.get("trust_mode") == "test",
		"test verification cannot masquerade as production trust")

	var original_receipt_text := FileAccess.get_file_as_string(receipt_path)
	var collision := AttestationScript.attest_with_test_trust_root(
		bundle_path,
		trust_root,
		"2026-07-19T18:00:01Z")
	_check(
		not collision["ok"]
			and collision["failure_code"]
				== FailureCodesScript.PUBLICATION_RECEIPT_COLLISION,
		"second publication of the same run fails with an append-only collision")
	_check(
		FileAccess.get_file_as_string(receipt_path) == original_receipt_text,
		"collision cannot overwrite the first receipt")

	_write_text(receipt_path, original_receipt_text + "\n")
	var receipt_reformat := AttestationScript.verify_with_test_trust_root(
		bundle_path,
		trust_root)
	_check(
		not receipt_reformat["ok"]
			and receipt_reformat["failure_code"]
				== FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
		"semantically identical noncanonical receipt bytes fail closed")
	_write_text(receipt_path, original_receipt_text)

	var original_tag := String(receipt["tag"])
	var final_nibble := "0" if not original_tag.ends_with("0") else "1"
	receipt["tag"] = original_tag.left(original_tag.length() - 1) + final_nibble
	_write_json(receipt_path, receipt)
	var tag_mutation := AttestationScript.verify_with_test_trust_root(
		bundle_path,
		trust_root)
	_check(
		not tag_mutation["ok"]
			and tag_mutation["failure_code"]
				== FailureCodesScript.PUBLICATION_TAG_MISMATCH,
		"one-nibble receipt mutation fails HMAC authentication")
	_write_text(receipt_path, original_receipt_text)
	_check(
		AttestationScript.verify_with_test_trust_root(
			bundle_path,
			trust_root)["ok"],
		"restoring the exact receipt restores authentication")

	var checksums_path := bundle_path.path_join("checksums.json")
	var original_checksums_text := FileAccess.get_file_as_string(checksums_path)
	_write_text(checksums_path, original_checksums_text + "\n")
	var exact_byte_mutation := AttestationScript.verify_with_test_trust_root(
		bundle_path,
		trust_root)
	_check(
		not exact_byte_mutation["ok"]
			and exact_byte_mutation["failure_code"]
				== FailureCodesScript.PUBLICATION_ENVELOPE_MISMATCH,
		"semantically identical but byte-different checksums.json is rejected")
	_write_text(checksums_path, original_checksums_text)
	_check(
		AttestationScript.verify_with_test_trust_root(
			bundle_path,
			trust_root)["ok"],
		"restoring exact bundle-index bytes restores verification")

	_build_bundle(bundle_path, run_id, "replacement-B")
	var coherent_rewrite := AttestationScript.verify_with_test_trust_root(
		bundle_path,
		trust_root)
	_check(
		not coherent_rewrite["ok"]
			and coherent_rewrite["failure_code"]
				== FailureCodesScript.PUBLICATION_ENVELOPE_MISMATCH,
		"internally consistent full-bundle replacement cannot forge provenance")
	var original_key_path := trust_root.path_join("keys").path_join(
		"%s.key" % key_id.trim_prefix("sha256:"))
	DirAccess.remove_absolute(original_key_path)
	var rewrite_without_key := AttestationScript.verify_with_test_trust_root(
		bundle_path,
		trust_root)
	_check(
		not rewrite_without_key["ok"]
			and rewrite_without_key["failure_code"]
				== FailureCodesScript.PUBLICATION_ENVELOPE_MISMATCH,
		"public envelope mismatch returns before any HMAC key lookup")
	_write_bytes(original_key_path, key)
	_build_bundle(bundle_path, run_id)
	_check(
		AttestationScript.verify_with_test_trust_root(
			bundle_path,
			trust_root)["ok"],
		"restoring the originally attested full bundle restores verification")

	var rotated_key_id := _install_key(trust_root, _key_bytes(32, 29))
	var after_rotation := AttestationScript.verify_with_test_trust_root(
		bundle_path,
		trust_root)
	_check(
		bool(after_rotation["ok"])
			and after_rotation["key_id"] == key_id
			and after_rotation["key_id"] != rotated_key_id,
		"active-key rotation retains verification through receipt key_id")


func _test_key_pointer_and_key_length_are_strict() -> void:
	print("- rejects malformed initializer pointers and non-32-byte keys")
	var bundle_path := _user_base.path_join("bundle-key-policy")
	_build_bundle(bundle_path, "attestation-key-policy-%s" % _token)
	var short_root := _temp_base.path_join("trust-short-key")
	_install_key(short_root, _key_bytes(31, 3))
	var short_result := AttestationScript.attest_with_test_trust_root(
		bundle_path,
		short_root,
		FIXED_TIME)
	_check(
		not short_result["ok"]
			and short_result["failure_code"]
				== FailureCodesScript.PUBLICATION_KEY_INVALID,
		"31-byte raw key fails closed")

	var long_root := _temp_base.path_join("trust-long-key")
	_install_key(long_root, _key_bytes(33, 4))
	var long_result := AttestationScript.attest_with_test_trust_root(
		bundle_path,
		long_root,
		FIXED_TIME)
	_check(
		not long_result["ok"]
			and long_result["failure_code"]
				== FailureCodesScript.PUBLICATION_KEY_INVALID,
		"33-byte raw key fails closed")

	var pointer_root := _temp_base.path_join("trust-bad-pointer")
	var valid_key := _key_bytes(32, 9)
	var pointer_key_id := _install_key(pointer_root, valid_key)
	_write_json(pointer_root.path_join("active_key.json"), {
		"schema_version": AttestationScript.ACTIVE_KEY_SCHEMA,
		"algorithm": AttestationScript.ALGORITHM,
		"key_id": pointer_key_id,
		"key_file": "../outside.key",
	})
	var pointer_result := AttestationScript.attest_with_test_trust_root(
		bundle_path,
		pointer_root,
		FIXED_TIME)
	_check(
		not pointer_result["ok"]
			and pointer_result["failure_code"]
				== FailureCodesScript.PUBLICATION_KEY_INVALID,
		"active key pointer cannot redirect outside its key-id-derived path")

	var extra_field_root := _temp_base.path_join("trust-extra-pointer-field")
	var extra_key_id := _install_key(extra_field_root, valid_key)
	_write_json(extra_field_root.path_join("active_key.json"), {
		"schema_version": AttestationScript.ACTIVE_KEY_SCHEMA,
		"algorithm": AttestationScript.ALGORITHM,
		"key_id": extra_key_id,
		"key_file": "keys/%s.key" % extra_key_id.trim_prefix("sha256:"),
		"unowned": true,
	})
	var extra_result := AttestationScript.attest_with_test_trust_root(
		bundle_path,
		extra_field_root,
		FIXED_TIME)
	_check(
		not extra_result["ok"]
			and extra_result["failure_code"]
				== FailureCodesScript.PUBLICATION_KEY_INVALID,
		"active key pointer rejects unowned fields")


func _test_missing_and_busy_receipts_fail_closed() -> void:
	print("- distinguishes absent receipts from an owned create-new lock")
	var missing_bundle := _user_base.path_join("bundle-missing")
	var missing_run_id := "attestation-missing-%s" % _token
	_build_bundle(missing_bundle, missing_run_id)
	var trust_root := _temp_base.path_join("trust-missing")
	_install_key(trust_root, _key_bytes(32, 21))
	var missing := AttestationScript.verify_with_test_trust_root(
		missing_bundle,
		trust_root)
	_check(
		not missing["ok"]
			and missing["failure_code"]
				== FailureCodesScript.PUBLICATION_RECEIPT_MISSING,
		"verification fails closed when detached receipt is absent")

	var busy_path := AttestationScript.receipt_path_for_run_id(
		trust_root,
		missing_run_id)
	DirAccess.make_dir_recursive_absolute(busy_path.get_base_dir())
	DirAccess.make_dir_absolute("%s.attestation-lock" % busy_path)
	var busy := AttestationScript.attest_with_test_trust_root(
		missing_bundle,
		trust_root,
		FIXED_TIME)
	_check(
		not busy["ok"]
			and busy["failure_code"]
				== FailureCodesScript.PUBLICATION_RECEIPT_BUSY,
		"existing reservation lock blocks a concurrent/stale writer")


func _test_trust_root_path_separation() -> void:
	print("- refuses trust roots that overlap output or repository state")
	var container := _temp_base.path_join("path-guards")
	var bundle_path := container.path_join("bundle")
	var nested_trust := bundle_path.path_join("trust")
	var nested_result := AttestationScript.attest_with_test_trust_root(
		bundle_path,
		nested_trust,
		FIXED_TIME)
	_check(
		not nested_result["ok"]
			and nested_result["failure_code"]
				== FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
		"trust root cannot be nested inside the bundle")

	var outer_trust := container.path_join("outer-trust")
	var nested_bundle := outer_trust.path_join("bundle")
	var inverse_result := AttestationScript.attest_with_test_trust_root(
		nested_bundle,
		outer_trust,
		FIXED_TIME)
	_check(
		not inverse_result["ok"]
			and inverse_result["failure_code"]
				== FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
		"bundle cannot be nested inside the trust root")

	var repository_root := _normalize(ProjectSettings.globalize_path("res://"))
	var repository_result := AttestationScript.attest_with_test_trust_root(
		bundle_path,
		repository_root.path_join("tmp-test-trust"),
		FIXED_TIME)
	_check(
		not repository_result["ok"]
			and repository_result["failure_code"]
				== FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
		"test injection cannot place trust material in the repository")
	var temp_root_result := AttestationScript.attest_with_test_trust_root(
		bundle_path,
		OS.get_temp_dir(),
		FIXED_TIME)
	_check(
		not temp_root_result["ok"]
			and temp_root_result["failure_code"]
				== FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
		"test injection requires a dedicated strict child of the OS temp root")


func _test_real_initializer_compatibility(trust_root: String) -> void:
	print("- consumes an actual PowerShell-initialized test trust root")
	var bundle_path := _user_base.path_join("bundle-real-initializer")
	_build_bundle(
		bundle_path,
		"attestation-real-initializer-%s" % _token)
	var attested := AttestationScript.attest_with_test_trust_root(
		bundle_path,
		trust_root,
		FIXED_TIME)
	_check(
		bool(attested["ok"]),
		"PowerShell initializer output signs without translation")
	if not attested["ok"]:
		printerr("    initializer compatibility failure: ", attested)
		return
	var verified := AttestationScript.verify_with_test_trust_root(
		bundle_path,
		trust_root)
	_check(
		bool(verified["ok"])
			and verified["key_id"] == attested["key_id"]
			and verified["trust_mode"] == "test",
		"PowerShell initializer output verifies with matching public identity")


func _build_bundle(
		bundle_path: String,
		run_id: String,
		variant: String = "original-A") -> void:
	DirAccess.make_dir_recursive_absolute(bundle_path)
	var manifest := {
		"schema": "sporespore.lab.manifest.v1",
		"run_id": run_id,
		"status": "COMPLETE",
		"experiment_id": "L0.0_ATTESTATION_FIXTURE",
		"schema_set": "sporespore.lab.schemas.v1",
		"recorder_version": "test-%s" % variant,
		"expanded_spec_sha256": HASH,
		"resolved_configuration_sha256": HASH,
		"applied_configuration_sha256": HASH,
		"dirty_worktree": false,
		"execution_mode": "promotion",
		"reproducibility": "clean_committed_source",
		"units": "SI",
		"started_utc": FIXED_TIME,
		"finalized_utc": "2026-07-19T18:00:01Z",
		"required_artifacts": [
			"manifest.json",
			"summary.json",
			"frames.jsonl",
			"events.jsonl",
		],
	}
	_write_json(bundle_path.path_join("manifest.json"), manifest)
	_write_json(bundle_path.path_join("summary.json"), {
		"run_id": run_id,
		"fixture": variant,
	})
	_write_text(
		bundle_path.path_join("frames.jsonl"),
		CanonicalJsonScript.stringify({
			"run_id": run_id,
			"frame": 0,
			"fixture": variant,
		}) + "\n")
	_write_text(
		bundle_path.path_join("events.jsonl"),
		CanonicalJsonScript.stringify({
			"run_id": run_id,
			"event": 0,
			"fixture": variant,
		}) + "\n")
	var artifacts: Dictionary = {}
	for artifact_name_value in [
		"manifest.json",
		"summary.json",
		"frames.jsonl",
		"events.jsonl",
	]:
		var artifact_name := String(artifact_name_value)
		var path := bundle_path.path_join(artifact_name)
		var is_jsonl: bool = artifact_name.ends_with(".jsonl")
		artifacts[artifact_name] = {
			"sha256": "sha256:%s" % FileAccess.get_sha256(path),
			"bytes": FileAccess.open(path, FileAccess.READ).get_length(),
			"kind": "jsonl" if is_jsonl else "json",
			"records": 1 if is_jsonl else null,
		}
	_write_json(bundle_path.path_join("checksums.json"), {
		"schema": "sporespore.lab.checksums.v1",
		"run_id": run_id,
		"algorithm": "sha256",
		"artifact_count": artifacts.size(),
		"artifacts": artifacts,
	})


func _install_key(trust_root: String, key: PackedByteArray) -> String:
	var key_id := _sha256_bytes(key)
	var key_hex := key_id.trim_prefix("sha256:")
	var key_directory := trust_root.path_join("keys")
	DirAccess.make_dir_recursive_absolute(key_directory)
	DirAccess.make_dir_recursive_absolute(trust_root.path_join("receipts"))
	var key_path := key_directory.path_join("%s.key" % key_hex)
	var key_file := FileAccess.open(key_path, FileAccess.WRITE)
	key_file.store_buffer(key)
	key_file.flush()
	key_file.close()
	_write_json(trust_root.path_join("active_key.json"), {
		"schema_version": AttestationScript.ACTIVE_KEY_SCHEMA,
		"algorithm": AttestationScript.ALGORITHM,
		"key_id": key_id,
		"key_file": "keys/%s.key" % key_hex,
	})
	return key_id


func _key_bytes(count: int, salt: int) -> PackedByteArray:
	var key := PackedByteArray()
	for index in count:
		key.append((index * 31 + salt) & 0xff)
	return key


func _sha256_bytes(value: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value)
	return "sha256:%s" % context.finish().hex_encode()


func _read_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"ok": false}
	if typeof(parser.data) != TYPE_DICTIONARY:
		return {"ok": false}
	return {
		"ok": true,
		"value": parser.data,
	}


func _write_json(path: String, value: Dictionary) -> void:
	_write_text(path, CanonicalJsonScript.stringify(value) + "\n")


func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.flush()
	file.close()


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.flush()
	file.close()


func _normalize(path: String) -> String:
	var value := path.replace("\\", "/")
	if value.begins_with("res://") or value.begins_with("user://"):
		value = ProjectSettings.globalize_path(value).replace("\\", "/")
	return value.simplify_path().trim_suffix("/")


func _argument_value(flag: String) -> String:
	var arguments := OS.get_cmdline_user_args()
	var index := arguments.find(flag)
	if index < 0 or index + 1 >= arguments.size():
		return ""
	return String(arguments[index + 1])


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
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
