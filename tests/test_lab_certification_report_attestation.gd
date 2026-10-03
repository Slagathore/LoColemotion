extends SceneTree
# gdlint: disable=max-file-lines
# The trust-boundary test keeps complete realistic report fixtures beside the
# adversarial mutations so schema and semantic coverage cannot drift apart.

const AttestationScript := preload(
	"res://scripts/lab/certification_report_attestation.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const CliScript := preload(
	"res://scripts/lab/certification_report_attestation_cli.gd")
const FailureCodesScript := preload("res://scripts/lab/failure_codes.gd")
const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")

const FIXED_TIME := "2026-07-19T19:00:00Z"
const COMMIT_SHA := "0123456789abcdef0123456789abcdef01234567"
const FIXTURE_KEY_ID := \
	"sha256:1111111111111111111111111111111111111111111111111111111111111111"

var _passed := 0
var _failed := 0
var _token := ""
var _temp_base := ""
var _production_before: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_token = "%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_temp_base = _normalize(
		OS.get_temp_dir()
			.path_join("SporeSporeCertificationReportAttestationTests")
			.path_join(_token))
	DirAccess.make_dir_recursive_absolute(_temp_base)
	_production_before = _trust_metadata(
		AttestationScript.production_trust_root())
	print("=== Lab BR1 certification-report attestation tests ===")
	_test_domain_separated_create_verify_tamper_and_collision()
	_test_v2_authoring_contract_create_and_verify()
	_test_key_and_identity_substitution()
	_test_missing_busy_and_invalid_report_identity()
	_test_strict_report_contract_rejections()
	_test_path_name_reparse_and_test_trust_guards()
	_test_cli_argument_contract()
	_test_production_trust_was_untouched()
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


func _test_domain_separated_create_verify_tamper_and_collision() -> void:
	print("- authenticates exact report bytes in a separate receipt domain")
	var evidence_root := _temp_base.path_join("primary-evidence")
	var report_path := evidence_root.path_join(AttestationScript.REPORT_NAME)
	var certification_id := "br1-primary-%s" % _token
	_build_report(report_path, certification_id)
	var trust_root := _temp_base.path_join("primary-trust")
	var key := _key_bytes(32, 17)
	var key_id := _install_key(trust_root, key)
	var attested := AttestationScript.attest_with_test_trust_root(
		report_path,
		certification_id,
		trust_root,
		FIXED_TIME)
	_check(bool(attested.get("ok", false)),
		"test trust root creates a detached report receipt")
	if not bool(attested.get("ok", false)):
		printerr("    attestation failure: ", attested)
		return
	_check(
		attested.get("trust_mode") == "test"
			and attested.get("can_promote") == false,
		"test receipt is explicitly valid but non-promotable")
	_check(attested.get("key_id") == key_id,
		"result exposes only the public key identity")
	_check(not attested.has("key"),
		"result never returns secret HMAC key bytes")
	_check(
		attested.get("report_sha256")
			== "sha256:%s" % FileAccess.get_sha256(report_path),
		"receipt authenticates the exact report bytes")
	_check(
		attested.get("report_bytes")
			== FileAccess.open(report_path, FileAccess.READ).get_length(),
		"receipt authenticates the exact report byte count")
	_check(
		attested.get("commit_sha") == COMMIT_SHA
			and attested.get("campaign_id") == AttestationScript.CAMPAIGN_ID
			and attested.get("campaign_sha256") == _campaign_sha256(),
		"receipt binds clean commit and fixed campaign identity")

	var receipt_path := String(attested["receipt_path"])
	var expected_receipt_path := (
		_normalize(trust_root)
			.path_join(AttestationScript.RECEIPT_DIRECTORY)
			.path_join("%s.json" % certification_id.sha256_text()))
	_check(
		_normalize(receipt_path) == expected_receipt_path,
		"receipt uses certification_reports/receipts and SHA-256(certification_id)")
	_check(
		not _normalize(receipt_path).begins_with(
			_normalize(trust_root).path_join("receipts").path_join("")),
		"report receipt cannot occupy the run-bundle receipt namespace")
	var receipt_result := _read_object(receipt_path)
	_check(bool(receipt_result.get("ok", false)),
		"installed receipt is readable JSON")
	if not bool(receipt_result.get("ok", false)):
		return
	var receipt: Dictionary = receipt_result["value"]
	var schema := SchemaValidatorScript.validate_file(
		AttestationScript.RECEIPT_SCHEMA_PATH,
		receipt)
	_check(bool(schema.get("ok", false)),
		"installed receipt passes its strict owned schema")
	var receipt_with_extra: Dictionary = receipt.duplicate(true)
	receipt_with_extra["unsigned_extension"] = true
	var extra_schema := SchemaValidatorScript.validate_file(
		AttestationScript.RECEIPT_SCHEMA_PATH,
		receipt_with_extra)
	_check(not bool(extra_schema.get("ok", true)),
		"strict schema rejects unsigned extension fields")
	_check(
		receipt.get("domain") == AttestationScript.RECEIPT_DOMAIN
			and receipt.get("schema") == AttestationScript.RECEIPT_SCHEMA,
		"receipt records the dedicated report HMAC domain and schema")

	var verified := AttestationScript.verify_with_test_trust_root(
		report_path,
		certification_id,
		trust_root)
	_check(bool(verified.get("ok", false)),
		"fresh detached report receipt verifies")
	_check(
		verified.get("receipt_sha256")
			== "sha256:%s" % FileAccess.get_sha256(receipt_path),
		"verification returns the exact installed receipt identity")

	var original_receipt_text := FileAccess.get_file_as_string(receipt_path)
	var collision := AttestationScript.attest_with_test_trust_root(
		report_path,
		certification_id,
		trust_root,
		"2026-07-19T19:00:01Z")
	_check(
		not bool(collision.get("ok", true))
			and collision.get("failure_code")
				== FailureCodesScript.PUBLICATION_RECEIPT_COLLISION,
		"second attestation of one certification ID fails append-only")
	_check(
		FileAccess.get_file_as_string(receipt_path) == original_receipt_text,
		"append-only collision cannot overwrite the original receipt")

	var original_report_text := FileAccess.get_file_as_string(report_path)
	_write_text(report_path, original_report_text + "\n")
	var byte_tamper := AttestationScript.verify_with_test_trust_root(
		report_path,
		certification_id,
		trust_root)
	_check(
		not bool(byte_tamper.get("ok", true))
			and byte_tamper.get("failure_code")
				== FailureCodesScript.PUBLICATION_ENVELOPE_MISMATCH,
		"semantically identical one-byte report mutation fails")
	_write_text(report_path, original_report_text)

	var coherent_rewrite: Dictionary = _report_object(certification_id)
	coherent_rewrite["generated_utc"] = "2026-07-19T19:00:01Z"
	_write_report(report_path, coherent_rewrite)
	var rewrite_result := AttestationScript.verify_with_test_trust_root(
		report_path,
		certification_id,
		trust_root)
	_check(
		not bool(rewrite_result.get("ok", true))
			and rewrite_result.get("failure_code")
				== FailureCodesScript.PUBLICATION_ENVELOPE_MISMATCH,
		"coherent full-report rewrite cannot manufacture provenance")
	_write_text(report_path, original_report_text)

	_write_text(receipt_path, original_receipt_text + "\n")
	var noncanonical_receipt := AttestationScript.verify_with_test_trust_root(
		report_path,
		certification_id,
		trust_root)
	_check(
		not bool(noncanonical_receipt.get("ok", true))
			and noncanonical_receipt.get("failure_code")
				== FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
		"semantically identical noncanonical receipt bytes fail closed")
	_write_text(receipt_path, original_receipt_text)

	var mutated_receipt: Dictionary = receipt.duplicate(true)
	var original_tag := String(mutated_receipt["tag"])
	mutated_receipt["tag"] = (
		original_tag.left(original_tag.length() - 1)
		+ ("0" if not original_tag.ends_with("0") else "1"))
	_write_json(receipt_path, mutated_receipt)
	var tag_tamper := AttestationScript.verify_with_test_trust_root(
		report_path,
		certification_id,
		trust_root)
	_check(
		not bool(tag_tamper.get("ok", true))
			and tag_tamper.get("failure_code")
				== FailureCodesScript.PUBLICATION_TAG_MISMATCH,
		"one-nibble HMAC mutation fails authentication")
	_write_text(receipt_path, original_receipt_text)
	_check(
		bool(AttestationScript.verify_with_test_trust_root(
			report_path,
			certification_id,
			trust_root).get("ok", false)),
		"restoring exact report and receipt bytes restores verification")


func _test_v2_authoring_contract_create_and_verify() -> void:
	print("- authors new evidence only in the report-v2 receipt domain")
	var evidence_root := _temp_base.path_join("v2-evidence")
	var report_path := evidence_root.path_join(AttestationScript.REPORT_NAME)
	var certification_id := "br1-v2-%s" % _token
	_write_report(report_path, _report_object(certification_id, true))
	var trust_root := _temp_base.path_join("v2-trust")
	_install_key(trust_root, _key_bytes(32, 47))
	var attested := AttestationScript.attest_v2_with_test_trust_root(
		report_path,
		certification_id,
		trust_root,
		FIXED_TIME)
	_check(bool(attested.get("ok", false))
		and String(attested.get("report_schema", ""))
			== AttestationScript.REPORT_SCHEMA_V2
		and String(attested.get("certification_contract_id", ""))
			== "BR1_L0_V2_CURRENT_I62"
		and attested.get("legacy_verification_only") == false,
		"v2 report fixture authenticates under the distinct current contract")
	if not bool(attested.get("ok", false)):
		printerr("    v2 attestation failure: ", attested)
		return
	_check(String(attested["receipt_path"]).replace("\\", "/").contains(
		"/certification_reports_v2/receipts/"),
		"v2 receipt is installed outside the legacy receipt namespace")
	var verified := AttestationScript.verify_v2_with_test_trust_root(
		report_path,
		certification_id,
		trust_root)
	_check(bool(verified.get("ok", false))
		and verified.get("receipt_sha256") == attested.get("receipt_sha256")
		and verified.get("can_promote") == false,
		"fresh v2 receipt verifies and remains non-promotable under a test root")


func _test_key_and_identity_substitution() -> void:
	print("- rejects key, HMAC-domain, and bundle-receipt substitution")
	var report_path := (
		_temp_base.path_join("substitution-evidence")
			.path_join(AttestationScript.REPORT_NAME))
	var certification_id := "br1-substitution-%s" % _token
	_build_report(report_path, certification_id)
	var trust_root := _temp_base.path_join("substitution-trust")
	var key := _key_bytes(32, 31)
	var original_key_id := _install_key(trust_root, key)
	var attested := AttestationScript.attest_with_test_trust_root(
		report_path,
		certification_id,
		trust_root,
		FIXED_TIME)
	_check(bool(attested.get("ok", false)),
		"substitution fixture receives its initial receipt")
	if not bool(attested.get("ok", false)):
		return
	var receipt_path := String(attested["receipt_path"])
	var original_receipt_text := FileAccess.get_file_as_string(receipt_path)
	var original_receipt: Dictionary = _read_object(receipt_path)["value"]

	var key_path := trust_root.path_join("keys").path_join(
		"%s.key" % original_key_id.trim_prefix("sha256:"))
	_write_bytes(key_path, _key_bytes(32, 99))
	var substituted_key := AttestationScript.verify_with_test_trust_root(
		report_path,
		certification_id,
		trust_root)
	_check(
		not bool(substituted_key.get("ok", true))
			and substituted_key.get("failure_code")
				== FailureCodesScript.PUBLICATION_KEY_INVALID,
		"same-path replacement key cannot substitute for its key_id")
	_write_bytes(key_path, key)

	var wrong_domain: Dictionary = original_receipt.duplicate(true)
	wrong_domain["domain"] = "sporespore.lab.publication_attestation.v1"
	wrong_domain.erase("tag")
	wrong_domain["tag"] = (
		"hmac-sha256:"
		+ AttestationScript.hmac_sha256_hex_for_test(
			key,
			CanonicalJsonScript.encode(wrong_domain)))
	_write_json(receipt_path, wrong_domain)
	var domain_substitution := AttestationScript.verify_with_test_trust_root(
		report_path,
		certification_id,
		trust_root)
	_check(
		not bool(domain_substitution.get("ok", true))
			and domain_substitution.get("failure_code")
				== FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
		"even an authentically tagged wrong-domain envelope is rejected")

	var bundle_receipt := {
		"schema": "sporespore.lab.publication_attestation.v1",
		"domain": "sporespore.lab.publication_attestation.v1",
		"algorithm": "hmac-sha256",
		"key_id": original_key_id,
		"run_id": certification_id,
		"checksums_sha256": _campaign_sha256(),
		"manifest_sha256": _campaign_sha256(),
		"artifact_count": 1,
		"attested_utc": FIXED_TIME,
		"tag": "hmac-sha256:" + "0".repeat(64),
	}
	_write_json(receipt_path, bundle_receipt)
	var bundle_substitution := AttestationScript.verify_with_test_trust_root(
		report_path,
		certification_id,
		trust_root)
	_check(
		not bool(bundle_substitution.get("ok", true))
			and bundle_substitution.get("failure_code")
				== FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
		"run-bundle receipt cannot substitute for report receipt")
	_write_text(receipt_path, original_receipt_text)

	var rotated_key_id := _install_key(trust_root, _key_bytes(32, 47))
	var after_rotation := AttestationScript.verify_with_test_trust_root(
		report_path,
		certification_id,
		trust_root)
	_check(
		bool(after_rotation.get("ok", false))
			and after_rotation.get("key_id") == original_key_id
			and after_rotation.get("key_id") != rotated_key_id,
		"active-key rotation preserves historical verification by recorded key_id")

	var wrong_certification := AttestationScript.verify_with_test_trust_root(
		report_path,
		"br1-other-%s" % _token,
		trust_root)
	_check(
		not bool(wrong_certification.get("ok", true))
			and wrong_certification.get("failure_code")
				== FailureCodesScript.EVIDENCE_INVALID,
		"embedded and requested certification identities cannot diverge")


func _test_missing_busy_and_invalid_report_identity() -> void:
	print("- fails closed on missing/busy receipts and weak report identity")
	var report_path := (
		_temp_base.path_join("missing-evidence")
			.path_join(AttestationScript.REPORT_NAME))
	var certification_id := "br1-missing-%s" % _token
	_build_report(report_path, certification_id)
	var trust_root := _temp_base.path_join("missing-trust")
	_install_key(trust_root, _key_bytes(32, 61))
	var missing := AttestationScript.verify_with_test_trust_root(
		report_path,
		certification_id,
		trust_root)
	_check(
		not bool(missing.get("ok", true))
			and missing.get("failure_code")
				== FailureCodesScript.PUBLICATION_RECEIPT_MISSING,
		"verification fails closed when report receipt is absent")
	var receipt_path := AttestationScript.receipt_path_for_certification_id(
		trust_root,
		certification_id)
	DirAccess.make_dir_recursive_absolute(receipt_path.get_base_dir())
	DirAccess.make_dir_absolute("%s.attestation-lock" % receipt_path)
	var busy := AttestationScript.attest_with_test_trust_root(
		report_path,
		certification_id,
		trust_root,
		FIXED_TIME)
	_check(
		not bool(busy.get("ok", true))
			and busy.get("failure_code")
				== FailureCodesScript.PUBLICATION_RECEIPT_BUSY,
		"owned create-new reservation blocks concurrent/stale attester")

	var invalid_time_report := (
		_temp_base.path_join("invalid-time-evidence")
			.path_join(AttestationScript.REPORT_NAME))
	var invalid_time_id := "br1-invalid-time-%s" % _token
	_build_report(invalid_time_report, invalid_time_id)
	var invalid_time_root := _temp_base.path_join("invalid-time-trust")
	_install_key(invalid_time_root, _key_bytes(32, 62))
	var invalid_time := AttestationScript.attest_with_test_trust_root(
		invalid_time_report,
		invalid_time_id,
		invalid_time_root,
		"not-a-time")
	_check(
		not bool(invalid_time.get("ok", true))
			and invalid_time.get("failure_code")
				== FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
		"invalid attestation timestamp cannot create a receipt")

	var weak_report_path := (
		_temp_base.path_join("weak-evidence")
			.path_join(AttestationScript.REPORT_NAME))
	var weak_id := "br1-weak-%s" % _token
	var weak_report := _report_object(weak_id)
	weak_report["repository"]["clean_at_all_recorded_gates"] = false
	_write_report(weak_report_path, weak_report)
	var weak_root := _temp_base.path_join("weak-trust")
	_install_key(weak_root, _key_bytes(32, 63))
	var weak_result := AttestationScript.attest_with_test_trust_root(
		weak_report_path,
		weak_id,
		weak_root,
		FIXED_TIME)
	_check(
		not bool(weak_result.get("ok", true))
			and weak_result.get("failure_code")
				== FailureCodesScript.EVIDENCE_INVALID,
		"report without clean status at every recorded gate cannot be authenticated")

	var bad_gate_id := "br1-bad-gate-%s" % _token
	var bad_gate := _report_object(bad_gate_id)
	bad_gate["repository"]["gates"][2]["checked_stage"] = "SUBSTITUTED_GATE"
	_write_report(weak_report_path, bad_gate)
	var bad_gate_result := AttestationScript.attest_with_test_trust_root(
		weak_report_path,
		bad_gate_id,
		weak_root,
		FIXED_TIME)
	_check(
		not bool(bad_gate_result.get("ok", true))
			and bad_gate_result.get("failure_code")
				== FailureCodesScript.EVIDENCE_INVALID,
		"missing, reordered, or renamed source observation gates fail closed")

	var absent_id := "br1-absent-identity-%s" % _token
	var absent_identity := _report_object(absent_id)
	absent_identity["campaign"].erase("sha256")
	_write_report(weak_report_path, absent_identity)
	var absent_result := AttestationScript.attest_with_test_trust_root(
		weak_report_path,
		absent_id,
		weak_root,
		FIXED_TIME)
	_check(
		not bool(absent_result.get("ok", true))
			and absent_result.get("failure_code")
				== FailureCodesScript.EVIDENCE_INVALID,
		"missing campaign digest fails before receipt creation")


func _test_strict_report_contract_rejections() -> void:
	print("- rejects incomplete or counter-only certification claims")
	var schema_id := "br1-schema-%s" % _token
	var complete_report := _report_object(schema_id)
	var complete_schema := SchemaValidatorScript.validate_file(
		AttestationScript.REPORT_SCHEMA_PATH,
		complete_report)
	_check(
		bool(complete_schema.get("ok", false)),
		"realistic pinned-suite, 7-cell, 14-run report passes owned schema")
	if not bool(complete_schema.get("ok", false)):
		printerr("    report schema errors: ", complete_schema.get("errors"))

	var weak_test_count_id := "br1-weak-tests-%s" % _token
	var weak_test_count := _report_object(weak_test_count_id)
	weak_test_count["test_inventory"]["passed"] = (
		AttestationScript.PINNED_TEST_COUNT - 1)
	_check(
		_strict_report_rejected(
			weak_test_count,
			weak_test_count_id,
			"weak-test-count"),
		"one-short test inventory cannot be authenticated as pass")

	var missing_count_id := "br1-missing-count-%s" % _token
	var missing_count := _report_object(missing_count_id)
	missing_count["campaign"].erase("bundles_passed")
	_check(
		_strict_report_rejected(
			missing_count,
			missing_count_id,
			"missing-campaign-count"),
		"missing campaign cardinality cannot be authenticated")

	var empty_cells_id := "br1-empty-cells-%s" % _token
	var empty_cells := _report_object(empty_cells_id)
	empty_cells["campaign"]["cells"] = []
	_check(
		_strict_report_rejected(
			empty_cells,
			empty_cells_id,
			"empty-cells"),
		"7/7 counters with an empty cell array cannot be authenticated")

	var wrong_engine_id := "br1-wrong-engine-%s" % _token
	var wrong_engine := _report_object(wrong_engine_id)
	wrong_engine["engine"]["observed_version"] = "4.7.fake"
	_check(
		_strict_report_rejected(
			wrong_engine,
			wrong_engine_id,
			"wrong-engine"),
		"wrong Godot build identity cannot be authenticated")

	var wrong_engine_gate_id := "br1-wrong-engine-gate-%s" % _token
	var wrong_engine_gate := _report_object(wrong_engine_gate_id)
	wrong_engine_gate["engine"]["identity_gates"][2][
		"executable_sha256"] = _fixture_sha("substituted-engine")
	_check(
		_strict_report_rejected(
			wrong_engine_gate,
			wrong_engine_gate_id,
			"wrong-engine-gate"),
		"one substituted engine observation gate fails closed")

	var child_substitution_id := "br1-child-substitution-%s" % _token
	var child_substitution := _report_object(child_substitution_id)
	child_substitution["engine"]["physics_child_executable"] = (
		"C:/Users/Cole/CodeStuff/Misc/Godot/SubstitutedGodot.exe")
	_check(
		_strict_report_rejected(
			child_substitution,
			child_substitution_id,
			"child-substitution"),
		"substituted physics-child executable fails closed")

	var wrong_child_hash_id := "br1-wrong-child-hash-%s" % _token
	var wrong_child_hash := _report_object(wrong_child_hash_id)
	wrong_child_hash["engine"][
		"observed_physics_child_executable_sha256"] = (
			_fixture_sha("substituted-physics-child"))
	_check(
		_strict_report_rejected(
			wrong_child_hash,
			wrong_child_hash_id,
			"wrong-child-hash"),
		"substituted physics-child digest fails closed")

	var wrong_child_gate_id := "br1-wrong-child-gate-%s" % _token
	var wrong_child_gate := _report_object(wrong_child_gate_id)
	wrong_child_gate["engine"]["physics_child_identity_gates"][1][
		"executable_sha256"] = _fixture_sha("substituted-child-gate")
	_check(
		_strict_report_rejected(
			wrong_child_gate,
			wrong_child_gate_id,
			"wrong-child-gate"),
		"one substituted physics-child observation gate fails closed")

	var console_process_id := "br1-console-process-%s" % _token
	var console_process := _report_object(console_process_id)
	var console_replicate: Dictionary = console_process[
		"campaign"]["cells"][0]["replicates"][0]
	console_replicate["process_identity"]["executable"] = (
		console_process["engine"]["executable"])
	console_replicate["final_sweep"]["process_identity"] = (
		console_replicate["process_identity"].duplicate(true))
	_check(
		_strict_report_rejected(
			console_process,
			console_process_id,
			"console-process"),
		"campaign process identity cannot substitute the operator console binary")

	var weak_readback_id := "br1-weak-readback-%s" % _token
	var weak_readback := _report_object(weak_readback_id)
	weak_readback["campaign"]["final_readback"][
		"retained_witnesses_match"] = false
	_check(
		_strict_report_rejected(
			weak_readback,
			weak_readback_id,
			"weak-final-readback"),
		"false retained-witness flag cannot be authenticated")

	var duplicate_process_id := "br1-duplicate-pid-%s" % _token
	var duplicate_process := _report_object(duplicate_process_id)
	var first_process: Dictionary = duplicate_process[
		"campaign"]["cells"][0]["replicates"][0]["process_identity"]
	var second_replicate: Dictionary = duplicate_process[
		"campaign"]["cells"][0]["replicates"][1]
	second_replicate["process_identity"]["outer_parent_process_id"] = (
		first_process["outer_parent_process_id"])
	second_replicate["process_identity"][
		"termination_observer_process_id"] = (
			first_process["outer_parent_process_id"])
	second_replicate["final_sweep"]["process_identity"] = (
		second_replicate["process_identity"].duplicate(true))
	_check(
		_strict_report_rejected(
			duplicate_process,
			duplicate_process_id,
			"duplicate-process"),
		"counter-only 14-process claim cannot hide a duplicated outer parent")

	var legal_recycle_id := "br1-legal-recycle-%s" % _token
	_check(
		_strict_report_accepted(
			_recycled_report(
				legal_recycle_id,
				"2026-07-19T19:00:02Z",
				"2026-07-19T19:00:03Z",
				true),
			legal_recycle_id,
			"legal-recycle"),
		"declared disjoint-window PID recycle authenticates")

	var hidden_recycle_id := "br1-hidden-recycle-%s" % _token
	_check(
		_strict_report_rejected(
			_recycled_report(
				hidden_recycle_id,
				"2026-07-19T19:00:02Z",
				"2026-07-19T19:00:03Z",
				false),
			hidden_recycle_id,
			"hidden-recycle"),
		"undeclared PID recycle cannot be authenticated")

	var overlap_recycle_id := "br1-overlap-recycle-%s" % _token
	_check(
		_strict_report_rejected(
			_recycled_report(
				overlap_recycle_id,
				FIXED_TIME,
				"2026-07-19T19:00:01Z",
				true),
			overlap_recycle_id,
			"overlap-recycle"),
		"overlapping same-PID run windows fail closed even when declared")

	var separator_root_id := "br1-separator-root-%s" % _token
	var separator_root := _report_object(separator_root_id)
	for gate_value in separator_root["repository"]["gates"]:
		var separator_gate: Dictionary = gate_value
		separator_gate["repository_root"] = "C:\\fixture\\SporeSpore"
	_check(
		_strict_report_accepted(
			separator_root,
			separator_root_id,
			"separator-root"),
		"git-style and native repository root separators identify one root")

	var altered_payload_id := "br1-altered-test-payload-%s" % _token
	var altered_payload := _report_object(altered_payload_id)
	altered_payload["test_inventory"]["report_bytes"] = (
		int(altered_payload["test_inventory"]["report_bytes"]) + 1)
	_check(
		_strict_report_rejected(
			altered_payload,
			altered_payload_id,
			"altered-test-payload"),
		"embedded test-report bytes must match their size and digest")

	var weak_result_id := "br1-weak-test-result-%s" % _token
	var weak_result := _report_object(weak_result_id)
	var weak_payload_bytes := Marshalls.base64_to_raw(String(
		weak_result["test_inventory"]["report_payload_base64"]))
	var weak_payload_parser := JSON.new()
	weak_payload_parser.parse(weak_payload_bytes.get_string_from_utf8())
	var weak_payload: Dictionary = weak_payload_parser.data
	weak_payload["results"][0]["footer_count"] = 0
	weak_payload_bytes = CanonicalJsonScript.encode(weak_payload)
	_write_bytes(
		String(weak_result["test_inventory"]["report_path"]),
		weak_payload_bytes)
	weak_result["test_inventory"]["report_sha256"] = _sha256_bytes(
		weak_payload_bytes)
	weak_result["test_inventory"]["report_bytes"] = weak_payload_bytes.size()
	weak_result["test_inventory"]["report_payload_base64"] = (
		Marshalls.raw_to_base64(weak_payload_bytes))
	_check(
		_strict_report_rejected(
			weak_result,
			weak_result_id,
			"weak-test-result"),
		"embedded test result without exactly one pass footer fails closed")

	var weak_operator_id := "br1-weak-operator-%s" % _token
	var weak_operator := _report_object(weak_operator_id)
	weak_operator["operator_self_tests"]["process_runner"][
		"process_tree_killed"] = false
	_check(
		_strict_report_rejected(
			weak_operator,
			weak_operator_id,
			"weak-operator-self-test"),
		"failed process-tree self-test cannot be authenticated")

	var weak_policy_id := "br1-weak-report-policy-%s" % _token
	var weak_policy := _report_object(weak_policy_id)
	weak_policy["detached_report_attestation"]["trust_mode"] = "test"
	_check(
		_strict_report_rejected(
			weak_policy,
			weak_policy_id,
			"weak-report-policy"),
		"weakened detached report-attestation policy fails closed")


func _recycled_report(
		certification_id: String,
		later_started_utc: String,
		later_ended_utc: String,
		declare_witness: bool) -> Dictionary:
	var report := _report_object(certification_id)
	var source: Dictionary = report["campaign"]["cells"][0]["replicates"][0]
	var target: Dictionary = report["campaign"]["cells"][3]["replicates"][1]
	var recycled_pid := int(
		source["process_identity"]["outer_parent_process_id"])
	target["process_identity"]["outer_parent_process_id"] = recycled_pid
	target["process_identity"]["termination_observer_process_id"] = (
		recycled_pid)
	target["process_identity"]["started_utc"] = later_started_utc
	target["process_identity"]["ended_utc"] = later_ended_utc
	target["final_sweep"]["process_identity"] = (
		target["process_identity"].duplicate(true))
	if declare_witness:
		report["campaign"]["pid_recycle_events"] = [{
			"role": "outer_parent",
			"process_id": recycled_pid,
			"earlier_run_id": String(source["run_id"]),
			"earlier_ended_utc": String(
				source["process_identity"]["ended_utc"]),
			"later_run_id": String(target["run_id"]),
			"later_started_utc": later_started_utc,
		}]
	return report


func _strict_report_accepted(
		report: Dictionary,
		certification_id: String,
		case_name: String) -> bool:
	var case_root := _temp_base.path_join("strict-%s" % case_name)
	var report_path := case_root.path_join(AttestationScript.REPORT_NAME)
	var trust_root := _temp_base.path_join("strict-%s-trust" % case_name)
	_write_report(report_path, report)
	_install_key(trust_root, _key_bytes(32, case_name.length() + 73))
	var result := AttestationScript.attest_with_test_trust_root(
		report_path,
		certification_id,
		trust_root,
		FIXED_TIME)
	return bool(result.get("ok", false))


func _strict_report_rejected(
		report: Dictionary,
		certification_id: String,
		case_name: String) -> bool:
	var case_root := _temp_base.path_join("strict-%s" % case_name)
	var report_path := case_root.path_join(AttestationScript.REPORT_NAME)
	var trust_root := _temp_base.path_join("strict-%s-trust" % case_name)
	_write_report(report_path, report)
	_install_key(trust_root, _key_bytes(32, case_name.length() + 73))
	var result := AttestationScript.attest_with_test_trust_root(
		report_path,
		certification_id,
		trust_root,
		FIXED_TIME)
	return (
		not bool(result.get("ok", true))
		and result.get("failure_code") == FailureCodesScript.EVIDENCE_INVALID
	)


func _test_path_name_reparse_and_test_trust_guards() -> void:
	print("- rejects unsafe names, overlaps, repository roots, and reparse paths")
	var evidence_root := _temp_base.path_join("path-evidence")
	var report_path := evidence_root.path_join(AttestationScript.REPORT_NAME)
	_build_report(report_path, "br1-path-%s" % _token)
	var trust_root := _temp_base.path_join("path-trust")
	_install_key(trust_root, _key_bytes(32, 71))
	var unsafe_id := AttestationScript.attest_with_test_trust_root(
		report_path,
		"../escape",
		trust_root,
		FIXED_TIME)
	_check(
		not bool(unsafe_id.get("ok", true))
			and unsafe_id.get("failure_code")
				== FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
		"certification ID cannot contain path traversal")
	_check(
		AttestationScript.receipt_path_for_certification_id(
			trust_root,
			"bad/name").is_empty(),
		"unsafe certification ID cannot derive a receipt path")

	var wrong_name := evidence_root.path_join("renamed_report.json")
	_write_report(wrong_name, _report_object())
	var wrong_name_result := AttestationScript.attest_with_test_trust_root(
		wrong_name,
		"br1-wrong-name-%s" % _token,
		trust_root,
		FIXED_TIME)
	_check(
		not bool(wrong_name_result.get("ok", true))
			and wrong_name_result.get("failure_code")
				== FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
		"report filename is fixed and cannot be caller-selected")

	var relative_result := AttestationScript.attest_with_test_trust_root(
		AttestationScript.REPORT_NAME,
		"br1-relative-%s" % _token,
		trust_root,
		FIXED_TIME)
	_check(
		not bool(relative_result.get("ok", true))
			and relative_result.get("failure_code")
				== FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
		"relative report paths fail closed")

	var overlap_result := AttestationScript.attest_with_test_trust_root(
		report_path,
		"br1-overlap-%s" % _token,
		evidence_root,
		FIXED_TIME)
	_check(
		not bool(overlap_result.get("ok", true))
			and overlap_result.get("failure_code")
				== FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
		"trust root cannot contain the certification report")

	var repository_root := _normalize(
		ProjectSettings.globalize_path("res://"))
	var repository_trust := AttestationScript.attest_with_test_trust_root(
		report_path,
		"br1-repository-trust-%s" % _token,
		repository_root.path_join("forbidden-test-trust"),
		FIXED_TIME)
	_check(
		not bool(repository_trust.get("ok", true))
			and repository_trust.get("failure_code")
				== FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
		"test trust injection cannot target the repository")
	var temp_root_result := AttestationScript.attest_with_test_trust_root(
		report_path,
		"br1-temp-root-%s" % _token,
		OS.get_temp_dir(),
		FIXED_TIME)
	_check(
		not bool(temp_root_result.get("ok", true))
			and temp_root_result.get("failure_code")
				== FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
		"test trust root must be a dedicated strict child of OS temp")

	var target_root := _temp_base.path_join("reparse-target")
	var target_report := target_root.path_join(AttestationScript.REPORT_NAME)
	_build_report(target_report, "br1-reparse-%s" % _token)
	var alias_root := _temp_base.path_join("reparse-alias")
	var base_directory := DirAccess.open(_temp_base)
	var link_error := ERR_UNAVAILABLE
	if base_directory != null:
		link_error = base_directory.create_link(target_root, alias_root)
	if link_error != OK and OS.get_name() == "Windows":
		# Directory junction creation does not require Developer Mode and lets
		# the Windows certification target exercise its real reparse-point
		# guard even when ordinary symlink creation is disabled.
		var junction_output: Array = []
		var junction_exit := OS.execute(
			"cmd.exe",
			PackedStringArray([
				"/d",
				"/c",
				"mklink",
				"/J",
				alias_root,
				target_root,
			]),
			junction_output,
			true,
			false)
		if (
			junction_exit == 0
			and DirAccess.dir_exists_absolute(alias_root)
		):
			link_error = OK
	_check(
		link_error == OK,
		"test fixture creates a real symbolic-link or Windows junction")
	if link_error == OK:
		var alias_result := AttestationScript.attest_with_test_trust_root(
			alias_root.path_join(AttestationScript.REPORT_NAME),
			"br1-reparse-%s" % _token,
			trust_root,
			FIXED_TIME)
		_check(
			not bool(alias_result.get("ok", true))
				and alias_result.get("failure_code")
					== FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"symbolic-link/reparse report ancestry fails closed")
		DirAccess.remove_absolute(alias_root)


func _test_cli_argument_contract() -> void:
	print("- pins the report-attestation CLI's machine argument contract")
	var valid := CliScript.parse_arguments(PackedStringArray([
		"--mode", "verify",
		"--report", "C:/evidence/br1_certification_report.json",
		"--certification-id", "br1-session-1",
		"--require-promotion",
	]))
	_check(
		bool(valid.get("ok", false))
			and valid["arguments"]["mode"] == "verify"
			and valid["arguments"]["require_promotion"] == true,
		"CLI accepts explicit verify and promotion policy")
	var test_attest := CliScript.parse_arguments(PackedStringArray([
		"--mode", "attest",
		"--report", "C:/evidence/br1_certification_report.json",
		"--certification-id", "br1-session-2",
		"--attestation-test-root", "C:/Temp/test-trust",
		"--attested-utc", FIXED_TIME,
	]))
	_check(bool(test_attest.get("ok", false)),
		"CLI permits deterministic time only on explicit test attestation")
	var production_time := CliScript.parse_arguments(PackedStringArray([
		"--mode", "attest",
		"--report", "C:/evidence/br1_certification_report.json",
		"--certification-id", "br1-session-3",
		"--attested-utc", FIXED_TIME,
	]))
	_check(not bool(production_time.get("ok", true)),
		"CLI rejects caller timestamps for production signing")
	var duplicate := CliScript.parse_arguments(PackedStringArray([
		"--mode", "verify",
		"--mode", "attest",
		"--report", "C:/evidence/br1_certification_report.json",
		"--certification-id", "br1-session-4",
	]))
	_check(not bool(duplicate.get("ok", true)),
		"CLI rejects duplicate arguments")
	var unknown := CliScript.parse_arguments(PackedStringArray([
		"--mode", "verify",
		"--report", "C:/evidence/br1_certification_report.json",
		"--certification-id", "br1-session-5",
		"--trust-root", "attacker-controlled",
	]))
	_check(not bool(unknown.get("ok", true)),
		"CLI has no production trust-root injection flag")


func _test_production_trust_was_untouched() -> void:
	print("- proves all test signing stayed outside production LabTrust")
	var production_after := _trust_metadata(
		AttestationScript.production_trust_root())
	_check(
		_production_before == production_after,
		"production trust-store metadata is exactly unchanged")
	var production_root := _normalize(
		AttestationScript.production_trust_root()).to_lower()
	var test_root := _normalize(_temp_base).to_lower()
	_check(
		production_root.is_empty()
			or (
				not test_root.begins_with(production_root + "/")
				and not production_root.begins_with(test_root + "/")
			),
		"isolated test roots do not overlap production trust")


func _report_object(
		certification_id: String = "br1-fixture-contract",
		use_v2: bool = false) -> Dictionary:
	var catalog := _campaign_catalog()
	var cells: Array = []
	for cell_index in 7:
		cells.append(_cell_object(catalog["cells"][cell_index], cell_index))
	var lab_test_fixture := _lab_test_report_fixture(use_v2)
	var operator_fixture := _operator_self_test_fixture()
	return {
		"schema": (
			AttestationScript.REPORT_SCHEMA_V2
			if use_v2 else AttestationScript.REPORT_SCHEMA),
		"status": AttestationScript.REPORT_STATUS,
		"certification": AttestationScript.CERTIFICATION,
		"claim_boundary": (
			"BR1 certifies only the L0 evidence pipeline. It establishes no "
			+ "standing, bracing, recovery, or walking capability."),
		"generated_utc": FIXED_TIME,
		"serialization": "ordered_compact_utf8_no_bom_v1",
		"repository": {
			"root": "C:/fixture/SporeSpore",
			"commit_sha": COMMIT_SHA,
			"clean_at_all_recorded_gates": true,
			"commit_unchanged_at_all_recorded_gates": true,
			"temporal_claim": (
				"Cleanliness and commit identity were observed at the "
				+ "listed gates; this does not claim continuous monitoring "
				+ "between gates."),
			"gates": [
				_source_gate("INITIAL"),
				_source_gate("AFTER_TESTS"),
				_source_gate("BEFORE_FINAL_SWEEP"),
				_source_gate("AFTER_FINAL_SWEEP"),
			],
		},
		"engine": {
			"executable": (
				"C:/Users/Cole/CodeStuff/Misc/Godot/"
				+ AttestationScript.EXPECTED_GODOT_EXECUTABLE_NAME),
			"expected_version": AttestationScript.EXPECTED_GODOT_VERSION,
			"observed_version": AttestationScript.EXPECTED_GODOT_VERSION,
			"expected_executable_sha256": (
				AttestationScript.EXPECTED_GODOT_EXECUTABLE_SHA256),
			"observed_executable_sha256": (
				AttestationScript.EXPECTED_GODOT_EXECUTABLE_SHA256),
			"product_version": (
				AttestationScript.EXPECTED_GODOT_PRODUCT_VERSION),
			"file_description": (
				AttestationScript.EXPECTED_GODOT_FILE_DESCRIPTION),
			"exact_build_match_at_all_recorded_gates": true,
			"identity_gates": [
				_engine_gate("INITIAL"),
				_engine_gate("AFTER_TESTS"),
				_engine_gate("BEFORE_FINAL_SWEEP"),
				_engine_gate("AFTER_FINAL_SWEEP"),
			],
			"physics_child_executable": (
				"C:/Users/Cole/CodeStuff/Misc/Godot/"
				+ AttestationScript.EXPECTED_PHYSICS_CHILD_EXECUTABLE_NAME),
			"expected_physics_child_executable_sha256": (
				AttestationScript.EXPECTED_PHYSICS_CHILD_EXECUTABLE_SHA256),
			"observed_physics_child_executable_sha256": (
				AttestationScript.EXPECTED_PHYSICS_CHILD_EXECUTABLE_SHA256),
			"physics_child_product_version": (
				AttestationScript.EXPECTED_PHYSICS_CHILD_PRODUCT_VERSION),
			"physics_child_file_description": (
				AttestationScript.EXPECTED_PHYSICS_CHILD_FILE_DESCRIPTION),
			"physics_child_exact_build_match_at_all_recorded_gates": true,
			"physics_child_identity_gates": [
				_physics_child_engine_gate("INITIAL"),
				_physics_child_engine_gate("AFTER_TESTS"),
				_physics_child_engine_gate("BEFORE_FINAL_SWEEP"),
				_physics_child_engine_gate("AFTER_FINAL_SWEEP"),
			],
		},
		"timeout_policy": {
			"per_test_seconds": 180,
			"lab_suite_seconds": 10800,
			"per_step_seconds": 900,
			"process_tree_kill_on_timeout": true,
			"process_runner_self_test": true,
		},
		"operator_self_tests": {
			"process_runner": {
				"pass": true,
				"success_exit": 0,
				"nonzero_exit": 37,
				"timeout_detected": true,
				"process_tree_killed": true,
				"inherited_descendant_terminated": true,
				"containment_tree_closed": true,
				"transcript_path": (
					operator_fixture["process_runner_path"]),
				"transcript_sha256": (
					operator_fixture["process_runner_sha256"]),
			},
			"attestation_initializer": {
				"pass": true,
				"assertions": 61,
				"production_store_touched": false,
				"transcript_path": (
					operator_fixture["initializer_path"]),
				"transcript_sha256": (
					operator_fixture["initializer_sha256"]),
			},
		},
		"attestation": {
			"requirement": "production_required",
			"algorithm": "hmac-sha256",
			"key_id": FIXTURE_KEY_ID,
			"trust_root": "C:/fixture/LabTrust/v1",
			"scope": (
				"Detects post-publication bundle replacement by a writer "
				+ "that cannot read or alter the external trust store."),
		},
		"detached_report_attestation": {
			"required": true,
			"timing": "after_complete_report_serialization",
			"report_rewrite_after_attestation_forbidden": true,
			"cli_resource": (
				"res://scripts/lab/"
				+ "certification_report_attestation_cli.gd"),
			"receipt_schema": (
				AttestationScript.RECEIPT_SCHEMA_V2
				if use_v2 else AttestationScript.RECEIPT_SCHEMA),
			"algorithm": "hmac-sha256",
			"trust_mode": "production",
			"certification_id": certification_id,
		},
		"test_inventory": {
			"path": _inventory_path(use_v2),
			"sha256": _inventory_sha256(use_v2),
			"required": (
				AttestationScript.PINNED_TEST_COUNT_V2
				if use_v2 else AttestationScript.PINNED_TEST_COUNT),
			"executed": (
				AttestationScript.PINNED_TEST_COUNT_V2
				if use_v2 else AttestationScript.PINNED_TEST_COUNT),
			"passed": (
				AttestationScript.PINNED_TEST_COUNT_V2
				if use_v2 else AttestationScript.PINNED_TEST_COUNT),
			"failed": 0,
			"missing": 0,
			"extra": 0,
			"report_path": lab_test_fixture["report_path"],
			"report_sha256": lab_test_fixture["report_sha256"],
			"report_bytes": lab_test_fixture["report_bytes"],
			"report_payload_base64": (
				lab_test_fixture["report_payload_base64"]),
			"artifacts": lab_test_fixture["artifacts"],
			"production_trust_store": {
				"unchanged": true,
				"before_sha256": _fixture_sha("production-trust-state"),
				"after_sha256": _fixture_sha("production-trust-state"),
				"entry_count": 0,
			},
		},
		"campaign": {
			"path": _campaign_path(),
			"sha256": _campaign_sha256(),
			"campaign_id": AttestationScript.CAMPAIGN_ID,
			"cells_required": 7,
			"cells_passed": 7,
			"bundles_required": 14,
			"bundles_passed": 14,
			"replays_required": 14,
			"replays_passed": 14,
			"replicate_comparisons_required": 7,
			"replicate_comparisons_passed": 7,
			"unique_outer_parent_processes": 14,
			"unique_physics_child_processes": 14,
			"pid_recycle_events": [],
			"final_readback": {
				"bundles_required": 14,
				"bundles_passed": 14,
				"replays_required": 14,
				"replays_passed": 14,
				"replicate_comparisons_required": 7,
				"replicate_comparisons_passed": 7,
				"retained_witnesses_match": true,
				"receipt_identities_match": true,
			},
			"cells": cells,
		},
	}


func _source_gate(stage: String) -> Dictionary:
	return {
		"clean": true,
		"commit_sha": COMMIT_SHA,
		"repository_root": "C:/fixture/SporeSpore",
		"checked_stage": stage,
	}


func _engine_gate(stage: String) -> Dictionary:
	return {
		"stage": stage,
		"executable_sha256": (
			AttestationScript.EXPECTED_GODOT_EXECUTABLE_SHA256),
		"product_version": AttestationScript.EXPECTED_GODOT_PRODUCT_VERSION,
		"file_description": AttestationScript.EXPECTED_GODOT_FILE_DESCRIPTION,
		"matches_pinned_build": true,
	}


func _physics_child_engine_gate(stage: String) -> Dictionary:
	return {
		"stage": stage,
		"executable_sha256": (
			AttestationScript.EXPECTED_PHYSICS_CHILD_EXECUTABLE_SHA256),
		"product_version": (
			AttestationScript.EXPECTED_PHYSICS_CHILD_PRODUCT_VERSION),
		"file_description": (
			AttestationScript.EXPECTED_PHYSICS_CHILD_FILE_DESCRIPTION),
		"matches_pinned_build": true,
	}


func _cell_object(catalog_cell: Dictionary, cell_index: int) -> Dictionary:
	var comparison := _comparison_object(cell_index)
	var replicates: Array = []
	for replicate in [1, 2]:
		replicates.append(_replicate_object(
			String(catalog_cell["cell_id"]),
			cell_index,
			replicate))
	var resource_path := String(catalog_cell["resource_path"])
	return {
		"cell_id": String(catalog_cell["cell_id"]),
		"resource_path": resource_path,
		"resource_sha256": _resource_sha256(resource_path),
		"root_seed": int(catalog_cell["seed_policy"]["root_seed"]),
		"observer_adapter": String(
			catalog_cell["observer"]["adapter_id"]),
		"observer_profile": String(
			catalog_cell["observer"]["primary_profile_id"]),
		"replicates": replicates,
		"comparison": comparison,
		"final_comparison": comparison.duplicate(true),
	}


func _replicate_object(
		cell_id: String,
		cell_index: int,
		replicate: int) -> Dictionary:
	var ordinal := cell_index * 2 + replicate
	var outer_parent_id := 10000 + ordinal
	var physics_child_id := 20000 + ordinal
	var run_id := "%s_pid-%d_r%d" % [
		cell_id.to_lower(),
		outer_parent_id,
		replicate,
	]
	var receipt_path := "C:/fixture/LabTrust/v1/receipts/%s.json" % run_id
	var manifest_sha := _fixture_sha("%s-manifest" % run_id)
	var checksums_sha := _fixture_sha("%s-checksums" % run_id)
	var summary_sha := _fixture_sha("%s-summary" % run_id)
	var process_sha := _fixture_sha("%s-process" % run_id)
	var launch_plan_sha := _fixture_sha("%s-launch-plan" % run_id)
	var receipt_sha := _fixture_sha("%s-receipt" % run_id)
	var process_identity := _process_identity_object(
		run_id,
		outer_parent_id,
		physics_child_id,
		ordinal,
		process_sha,
		launch_plan_sha)
	var validation := _validation_object(
		run_id,
		receipt_path,
		receipt_sha)
	var replay := _replay_object(run_id)
	return {
		"replicate": replicate,
		"run_id": run_id,
		"experiment_id": cell_id,
		"physics_ticks_per_second": _physics_hz(cell_id),
		"bundle_path": "C:/fixture/evidence/%s" % run_id,
		"bundle_manifest_sha256": manifest_sha,
		"bundle_checksums_sha256": checksums_sha,
		"bundle_summary_sha256": summary_sha,
		"process_metadata_sha256": process_sha,
		"launch_plan_sha256": launch_plan_sha,
		"replicate_root": "C:/fixture/evidence/cell-%d/r%d" % [
			cell_index + 1,
			replicate,
		],
		"launch": {
			"exit_code": 0,
			"duration_ms": 1000 + ordinal,
			"engine_log": "C:/fixture/logs/%s.outer.log" % run_id,
			"sealed_child_engine_log": (
				"C:/fixture/evidence/%s/engine.log" % run_id),
			"transcript": "C:/fixture/logs/%s.transcript.log" % run_id,
		},
		"attestation": {
			"valid": true,
			"algorithm": "hmac-sha256",
			"key_id": FIXTURE_KEY_ID,
			"receipt_path": receipt_path,
			"receipt_sha256": receipt_sha,
			"trust_mode": "production",
		},
		"process_identity": process_identity,
		"independent_validation": validation,
		"replay": replay,
		"final_sweep": {
			"pass": true,
			"retained_witness_match": true,
			"production_attestation_required": true,
			"promotion_required": true,
			"manifest_sha256": manifest_sha,
			"checksums_sha256": checksums_sha,
			"summary_sha256": summary_sha,
			"process_metadata_sha256": process_sha,
			"launch_plan_sha256": launch_plan_sha,
			"receipt_path": receipt_path,
			"receipt_sha256": receipt_sha,
			"process_identity": process_identity.duplicate(true),
			"validation": validation.duplicate(true),
			"replay": replay.duplicate(true),
		},
	}


func _process_identity_object(
		run_id: String,
		outer_parent_id: int,
		physics_child_id: int,
		ordinal: int,
		process_sha: String,
		launch_plan_sha: String) -> Dictionary:
	return {
		"outer_parent_process_id": outer_parent_id,
		"physics_child_process_id": physics_child_id,
		"termination_observer_process_id": outer_parent_id,
		"reservation_id": "%032d" % ordinal,
		"process_metadata_sha256": process_sha,
		"launch_plan_sha256": launch_plan_sha,
		"launch_plan_payload_sha256": _fixture_sha(
			"%s-launch-payload" % run_id),
		"started_utc": FIXED_TIME,
		"ended_utc": "2026-07-19T19:00:01Z",
		"executable": (
			"C:/Users/Cole/CodeStuff/Misc/Godot/"
			+ AttestationScript.EXPECTED_PHYSICS_CHILD_EXECUTABLE_NAME),
		"argument_capture_quality": "launcher_exact",
		"exact_argument_match": true,
		"run_id_parent_pid_binding": true,
	}


func _validation_object(
		run_id: String,
		receipt_path: String,
		receipt_sha: String) -> Dictionary:
	return {
		"can_finalize": true,
		"can_promote": true,
		"result_sha256": _fixture_sha("%s-validation" % run_id),
		"publication_attestation": {
			"valid": true,
			"trust_mode": "production",
			"key_id": FIXTURE_KEY_ID,
			"receipt_path": receipt_path,
			"receipt_sha256": receipt_sha,
			"run_id": run_id,
			"attested_utc": FIXED_TIME,
		},
		"engine_log": "C:/fixture/logs/%s.validator.engine.log" % run_id,
		"transcript": "C:/fixture/logs/%s.validator.log" % run_id,
	}


func _replay_object(run_id: String) -> Dictionary:
	return {
		"pass": true,
		"simulation_steps": 0,
		"frames": 120,
		"events": 1,
		"production_attestation_required": true,
		"engine_log": "C:/fixture/logs/%s.replay.engine.log" % run_id,
		"transcript": "C:/fixture/logs/%s.replay.log" % run_id,
	}


func _comparison_object(cell_index: int) -> Dictionary:
	var digest := _fixture_sha("cell-%d-evidence" % cell_index)
	return {
		"pass": true,
		"comparator_id": (
			"sporespore.lab.br1_l0_replicate_comparator.v1"),
		"mismatch_count": 0,
		"production_attestation_required": true,
		"left_evidence_digest": digest,
		"right_evidence_digest": digest,
		"result_sha256": _fixture_sha("cell-%d-comparison" % cell_index),
		"engine_log": "C:/fixture/logs/cell-%d.compare.engine.log" % cell_index,
		"transcript": "C:/fixture/logs/cell-%d.compare.log" % cell_index,
	}


func _physics_hz(cell_id: String) -> int:
	if cell_id.contains("_30HZ_"):
		return 30
	if cell_id.contains("_120HZ_"):
		return 120
	return 60


func _fixture_sha(label: String) -> String:
	return "sha256:%s" % label.sha256_text()


func _campaign_catalog() -> Dictionary:
	var parser := JSON.new()
	var error := parser.parse(FileAccess.get_file_as_string(
		AttestationScript.CAMPAIGN_RESOURCE_PATH))
	return parser.data if error == OK else {}


func _resource_sha256(resource_path: String) -> String:
	return "sha256:%s" % FileAccess.get_sha256(
		ProjectSettings.globalize_path(resource_path))


func _campaign_path() -> String:
	return _normalize(ProjectSettings.globalize_path(
		AttestationScript.CAMPAIGN_RESOURCE_PATH))


func _campaign_sha256() -> String:
	return _resource_sha256(AttestationScript.CAMPAIGN_RESOURCE_PATH)


func _inventory_path(use_v2: bool = false) -> String:
	return _normalize(ProjectSettings.globalize_path(
		_inventory_resource_path(use_v2)))


func _inventory_sha256(use_v2: bool = false) -> String:
	return _resource_sha256(_inventory_resource_path(use_v2))


func _inventory_resource_path(use_v2: bool) -> String:
	return (
		AttestationScript.INVENTORY_RESOURCE_PATH_V2
		if use_v2 else AttestationScript.INVENTORY_RESOURCE_PATH)


func _lab_test_report_fixture(use_v2: bool = false) -> Dictionary:
	var inventory_resource_path := _inventory_resource_path(use_v2)
	var pinned_count := (
		AttestationScript.PINNED_TEST_COUNT_V2
		if use_v2 else AttestationScript.PINNED_TEST_COUNT)
	var inventory_parser := JSON.new()
	var parse_error := inventory_parser.parse(
		FileAccess.get_file_as_string(
			inventory_resource_path))
	var inventory: Dictionary = (
		inventory_parser.data if parse_error == OK else {})
	var fixture_root := _temp_base.path_join(
		"embedded-lab-test-fixture-v2"
		if use_v2 else "embedded-lab-test-fixture-v1")
	var results: Array = []
	var artifacts: Array = []
	for test_value in inventory.get("tests", []):
		var test_name := String(test_value)
		var stem := test_name.trim_suffix(".gd")
		var engine_path := fixture_root.path_join(
			"%s.engine.log" % stem)
		var transcript_path := fixture_root.path_join(
			"%s.transcript.log" % stem)
		var engine_bytes := (
			"fixture engine log for %s\n" % test_name).to_utf8_buffer()
		var transcript_bytes := (
			"fixture transcript for %s\n" % test_name).to_utf8_buffer()
		_write_bytes(engine_path, engine_bytes)
		_write_bytes(transcript_path, transcript_bytes)
		artifacts.append(_test_artifact(
			test_name,
			"engine_log",
			engine_path,
			engine_bytes))
		artifacts.append(_test_artifact(
			test_name,
			"transcript_log",
			transcript_path,
			transcript_bytes))
		results.append({
			"test": test_name,
			"status": "pass",
			"process_exit_code": 0,
			"timed_out": false,
			"containment_tree_closed": true,
			"exit_marker_observed": true,
			"timeout_seconds": 180,
			"killed_process_tree": false,
			"process_start_error": "",
			"process_termination_error": "",
			"footer_found": true,
			"footer_count": 1,
			"assertions_passed": 1,
			"assertions_failed": 0,
			"engine_log_exists": true,
			"engine_log_readable": true,
			"transcript_log_exists": true,
			"transcript_log_readable": true,
			"engine_log_sha256": _sha256_bytes(engine_bytes),
			"transcript_log_sha256": _sha256_bytes(transcript_bytes),
			"engine_log_bytes": engine_bytes.size(),
			"transcript_log_bytes": transcript_bytes.size(),
			"engine_error_count": 0,
			"engine_errors": [],
			"expected_engine_error_codes": [],
			"unexpected_engine_errors": [],
			"missing_expected_engine_error_codes": [],
			"unknown_expected_engine_error_codes": [],
			"duration_ms": 1,
			"engine_log": engine_path,
			"transcript_log": transcript_path,
		})
	var test_report := {
		"schema": "sporespore.lab.test_report.v1",
		"started_utc": FIXED_TIME,
		"generated_utc": "2026-07-19T19:00:01Z",
		"godot": (
			"C:/Users/Cole/CodeStuff/Misc/Godot/"
			+ AttestationScript.EXPECTED_GODOT_EXECUTABLE_NAME),
		"repository": "C:/fixture/SporeSpore",
		"pattern": "test_lab_*.gd",
		"test_timeout_seconds": 180,
		"total": pinned_count,
		"passed": pinned_count,
		"failed": 0,
		"results": results,
	}
	var report_bytes := CanonicalJsonScript.encode(test_report)
	var report_path := fixture_root.path_join("report.json")
	_write_bytes(report_path, report_bytes)
	return {
		"report_path": report_path,
		"report_sha256": _sha256_bytes(report_bytes),
		"report_bytes": report_bytes.size(),
		"report_payload_base64": Marshalls.raw_to_base64(report_bytes),
		"artifacts": artifacts,
	}


func _operator_self_test_fixture() -> Dictionary:
	var fixture_root := _temp_base.path_join("operator-self-test-fixture")
	var process_runner_path := fixture_root.path_join(
		"process_runner.transcript.log")
	var initializer_path := fixture_root.path_join(
		"initializer.transcript.log")
	var process_runner_bytes := (
		"PROCESS_RUNNER_SELF_TEST pass=true success_exit=0 "
		+ "timeout_detected=True process_tree_killed=True\n"
		+ "PROCESS_RUNNER_SELF_TEST nonzero_exit=37 "
		+ "inherited_descendant_terminated=True "
		+ "containment_tree_closed=True\n").to_utf8_buffer()
	var initializer_bytes := (
		"LAB_ATTESTATION_INITIALIZER_SELF_TEST pass=true assertions=61 "
		+ "production_store_touched=false\n").to_utf8_buffer()
	_write_bytes(process_runner_path, process_runner_bytes)
	_write_bytes(initializer_path, initializer_bytes)
	return {
		"process_runner_path": process_runner_path,
		"process_runner_sha256": _sha256_bytes(process_runner_bytes),
		"initializer_path": initializer_path,
		"initializer_sha256": _sha256_bytes(initializer_bytes),
	}


func _test_artifact(
		test_name: String,
		kind: String,
		path: String,
		bytes: PackedByteArray) -> Dictionary:
	return {
		"test": test_name,
		"kind": kind,
		"path": path,
		"sha256": _sha256_bytes(bytes),
		"bytes": bytes.size(),
	}


func _build_report(path: String, certification_id: String) -> void:
	_write_report(path, _report_object(certification_id))


func _write_report(path: String, value: Dictionary) -> void:
	# The production PowerShell serializer writes compact UTF-8 without BOM or
	# trailing newline. The HMAC still authenticates bytes, not this convention.
	_write_text(path, CanonicalJsonScript.stringify(value))


func _install_key(trust_root: String, key: PackedByteArray) -> String:
	var key_id := _sha256_bytes(key)
	var key_hex := key_id.trim_prefix("sha256:")
	var key_directory := trust_root.path_join("keys")
	DirAccess.make_dir_recursive_absolute(key_directory)
	DirAccess.make_dir_recursive_absolute(
		trust_root.path_join("certification_reports").path_join("receipts"))
	_write_bytes(key_directory.path_join("%s.key" % key_hex), key)
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


func _trust_metadata(path: String) -> PackedStringArray:
	var result := PackedStringArray()
	var normalized := _normalize(path)
	if normalized.is_empty() or not DirAccess.dir_exists_absolute(normalized):
		result.append("<missing>")
		return result
	_collect_metadata(normalized, normalized, result)
	result.sort()
	return result


func _collect_metadata(
		root: String,
		path: String,
		result: PackedStringArray) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		result.append("<unreadable>:%s" % path.trim_prefix(root))
		return
	directory.include_hidden = true
	var names := PackedStringArray()
	names.append_array(directory.get_directories())
	names.append_array(directory.get_files())
	names.sort()
	for name in names:
		var child := path.path_join(name)
		var relative := child.trim_prefix(root).trim_prefix("/")
		if directory.is_link(name):
			result.append("link:%s" % relative)
		elif DirAccess.dir_exists_absolute(child):
			result.append("dir:%s" % relative)
			_collect_metadata(root, child, result)
		else:
			var file := FileAccess.open(child, FileAccess.READ)
			var length := file.get_length() if file != null else -1
			if file != null:
				file.close()
			result.append(
				"file:%s:%d:%d"
				% [relative, length, FileAccess.get_modified_time(child)])


func _normalize(path: String) -> String:
	var value := path.strip_edges().replace("\\", "/")
	if value.begins_with("res://") or value.begins_with("user://"):
		value = ProjectSettings.globalize_path(value).replace("\\", "/")
	return value.simplify_path().trim_suffix("/")


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
		if directory.is_link(name):
			DirAccess.remove_absolute(child)
		elif directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)
