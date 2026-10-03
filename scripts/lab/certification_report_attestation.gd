class_name LabCertificationReportAttestation
extends RefCounted
# gdlint: disable=max-file-lines
# Report authentication, strict report qualification, append-only publication,
# and path/key hardening intentionally remain one auditable trust boundary.

## Detached, domain-separated authentication for the final BR1 report.
##
## A run bundle receipt and a certification-report receipt deliberately use:
## - different schemas and HMAC domains;
## - different receipt directories;
## - different identity keys (run_id versus certification_id).
##
## The receipt authenticates the exact report bytes plus the clean source
## commit and fixed campaign identity extracted from those same bytes. It is
## stored outside both the report/evidence store and the repository.
##
## Threat boundary:
## - protects against a writer limited to the report/evidence output store;
## - does not protect against an account/admin or process that can read the
##   HMAC key, mutate this verifier, or alter the protected trust store;
## - test-root APIs are explicit and always return can_promote=false.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FailureCodesScript := preload("res://scripts/lab/failure_codes.gd")
const PublicationAttestationScript := preload(
	"res://scripts/lab/publication_attestation.gd")
const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")
const QualificationRegistryScript := preload(
	"res://scripts/lab/certification_qualification_profile_registry.gd")

const RECEIPT_SCHEMA := \
	"sporespore.lab.br1_certification_report_attestation.v1"
const RECEIPT_DOMAIN := \
	"sporespore.lab.br1_certification_report_attestation.v1"
const REPORT_SCHEMA := "sporespore.lab.br1_certification_report.v1"
const REPORT_STATUS := "pass"
const CERTIFICATION := "BR1_L0_EVIDENCE_PIPELINE"
const CAMPAIGN_ID := "BR1_L0_CERTIFICATION_V1"
const REPORT_NAME := "br1_certification_report.json"
const ALGORITHM := "hmac-sha256"
const ACTIVE_KEY_SCHEMA := "sporespore.lab_attestation.active_key.v1"
const ACTIVE_KEY_FILE := "active_key.json"
const RECEIPT_DIRECTORY := "certification_reports/receipts"
const RECEIPT_DIRECTORY_V2 := "certification_reports_v2/receipts"
const RECEIPT_SCHEMA_PATH := \
	"res://data/lab/schemas/certification_report_attestation_v1.schema.json"
const REPORT_SCHEMA_PATH := \
	"res://data/lab/schemas/br1_certification_report_v1.schema.json"
const CAMPAIGN_RESOURCE_PATH := \
	"res://data/lab/campaigns/BR1_L0_certification_v1.json"
const INVENTORY_RESOURCE_PATH := \
	"res://data/lab/campaigns/BR1_required_lab_tests_v1.json"
const RECEIPT_SCHEMA_V2 := \
	"sporespore.lab.br1_certification_report_attestation.v2"
const REPORT_SCHEMA_V2 := "sporespore.lab.br1_certification_report.v2"
const RECEIPT_SCHEMA_PATH_V2 := \
	"res://data/lab/schemas/certification_report_attestation_v2.schema.json"
const REPORT_SCHEMA_PATH_V2 := \
	"res://data/lab/schemas/br1_certification_report_v2.schema.json"
const INVENTORY_RESOURCE_PATH_V2 := \
	"res://data/lab/campaigns/BR1_required_lab_tests_v2.json"
## The exact pinned lab-suite size. This revs together with the inventory
## JSON content and the operator's ExpectedTestCount and
## ExpectedTestInventorySha256 pins, never alone: 45 became 51 when BR2
## landed its six pinned observation tests. Every count comparison in this
## validator derives from this one constant so the next deliberate rev is a
## single-line change on each side of the contract.
const PINNED_TEST_COUNT := 51
const PINNED_TEST_ARTIFACT_COUNT := PINNED_TEST_COUNT * 2
const PINNED_TEST_COUNT_V2 := 62
const PINNED_TEST_ARTIFACT_COUNT_V2 := PINNED_TEST_COUNT_V2 * 2
const EXPECTED_GODOT_VERSION := "4.7.stable.mono.official.5b4e0cb0f"
const EXPECTED_GODOT_EXECUTABLE_SHA256 := \
	"sha256:c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
const EXPECTED_GODOT_PRODUCT_VERSION := "4.7.stable.mono.official"
const EXPECTED_GODOT_FILE_DESCRIPTION := "Godot Engine (Console)"
const EXPECTED_GODOT_EXECUTABLE_NAME := \
	"Godot_v4.7-stable_mono_win64_console.exe"
const EXPECTED_PHYSICS_CHILD_EXECUTABLE_SHA256 := \
	"sha256:baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4"
const EXPECTED_PHYSICS_CHILD_PRODUCT_VERSION := "4.7.stable.mono.official"
const EXPECTED_PHYSICS_CHILD_FILE_DESCRIPTION := "Godot Engine"
const EXPECTED_PHYSICS_CHILD_EXECUTABLE_NAME := \
	"Godot_v4.7-stable_mono_win64.exe"
const KEY_BYTES := 32
const MAX_REPORT_BYTES := 64 * 1024 * 1024


static func production_trust_root() -> String:
	return PublicationAttestationScript.production_trust_root()


static func attest_production(
		report_path: String,
		certification_id: String) -> Dictionary:
	return _failure(
		FailureCodesScript.LEGACY_CERTIFICATION_AUTHORING_DISABLED,
		"BR1 report-v1 is verification-only; author new evidence with the v2 contract.",
		{
			"report_path": report_path,
			"certification_id": certification_id,
		})


static func attest_production_v2(
		report_path: String,
		certification_id: String) -> Dictionary:
	var trust_root := production_trust_root()
	if trust_root.is_empty():
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"LOCALAPPDATA is unavailable; the fixed production trust root cannot be resolved.")
	return _attest(
		report_path,
		certification_id,
		trust_root,
		"",
		"production",
		_v2_contract())


static func verify_production(
		report_path: String,
		certification_id: String) -> Dictionary:
	var trust_root := production_trust_root()
	if trust_root.is_empty():
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"LOCALAPPDATA is unavailable; the fixed production trust root cannot be resolved.")
	var legacy := _legacy_contract_for_report(report_path)
	if not bool(legacy.get("ok", false)):
		return legacy
	return _verify(
		report_path,
		certification_id,
		trust_root,
		"production",
		legacy["contract"])


static func verify_production_v2(
		report_path: String,
		certification_id: String) -> Dictionary:
	var trust_root := production_trust_root()
	if trust_root.is_empty():
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"LOCALAPPDATA is unavailable; the fixed production trust root cannot be resolved.")
	return _verify(
		report_path,
		certification_id,
		trust_root,
		"production",
		_v2_contract())


static func attest_with_test_trust_root(
		report_path: String,
		certification_id: String,
		test_trust_root: String,
		attested_utc: String = "") -> Dictionary:
	var root_result := _validate_test_trust_root(test_trust_root)
	if not root_result["ok"]:
		return root_result
	var legacy := _legacy_contract_for_report(report_path)
	if not bool(legacy.get("ok", false)):
		return legacy
	return _attest(
		report_path,
		certification_id,
		String(root_result["trust_root"]),
		attested_utc,
		"test",
		legacy["contract"])


static func attest_v2_with_test_trust_root(
		report_path: String,
		certification_id: String,
		test_trust_root: String,
		attested_utc: String = "") -> Dictionary:
	var root_result := _validate_test_trust_root(test_trust_root)
	if not root_result["ok"]:
		return root_result
	return _attest(
		report_path,
		certification_id,
		String(root_result["trust_root"]),
		attested_utc,
		"test",
		_v2_contract())


static func verify_with_test_trust_root(
		report_path: String,
		certification_id: String,
		test_trust_root: String) -> Dictionary:
	var root_result := _validate_test_trust_root(test_trust_root)
	if not root_result["ok"]:
		return root_result
	var legacy := _legacy_contract_for_report(report_path)
	if not bool(legacy.get("ok", false)):
		return legacy
	return _verify(
		report_path,
		certification_id,
		String(root_result["trust_root"]),
		"test",
		legacy["contract"])


static func verify_v2_with_test_trust_root(
		report_path: String,
		certification_id: String,
		test_trust_root: String) -> Dictionary:
	var root_result := _validate_test_trust_root(test_trust_root)
	if not root_result["ok"]:
		return root_result
	return _verify(
		report_path,
		certification_id,
		String(root_result["trust_root"]),
		"test",
		_v2_contract())


static func receipt_path_for_certification_id(
		trust_root: String,
		certification_id: String) -> String:
	if not _is_safe_certification_id(certification_id):
		return ""
	var normalized_root := _normalized_absolute(trust_root)
	if normalized_root.is_empty():
		return ""
	return normalized_root.path_join(RECEIPT_DIRECTORY).path_join(
		"%s.json" % certification_id.sha256_text())


static func receipt_path_for_certification_id_v2(
		trust_root: String,
		certification_id: String) -> String:
	return _receipt_path(
		trust_root, certification_id, _v2_contract())


static func _receipt_path(
		trust_root: String,
		certification_id: String,
		contract: Dictionary) -> String:
	if not _is_safe_certification_id(certification_id):
		return ""
	var normalized_root := _normalized_absolute(trust_root)
	if normalized_root.is_empty():
		return ""
	return normalized_root.path_join(
		String(contract["receipt_directory"])).path_join(
		"%s.json" % certification_id.sha256_text())


static func _v2_contract() -> Dictionary:
	return {
		"contract_id": "BR1_L0_V2_CURRENT_I62",
		"qualification_profile_id": null,
		"legacy_verification_only": false,
		"receipt_schema": RECEIPT_SCHEMA_V2,
		"receipt_domain": RECEIPT_SCHEMA_V2,
		"receipt_schema_validation_path": RECEIPT_SCHEMA_PATH_V2,
		"receipt_directory": RECEIPT_DIRECTORY_V2,
		"report_schema": REPORT_SCHEMA_V2,
		"report_schema_validation_path": REPORT_SCHEMA_PATH_V2,
		"inventory_schema":
			"sporespore.lab.br1_required_test_inventory.v2",
		"inventory_id": "BR1_REQUIRED_LAB_TESTS_V2",
		"inventory_version": 2,
		"inventory_report_resource_path": INVENTORY_RESOURCE_PATH_V2,
		"inventory_validation_resource_path": INVENTORY_RESOURCE_PATH_V2,
		"test_count": PINNED_TEST_COUNT_V2,
		"artifact_count": PINNED_TEST_ARTIFACT_COUNT_V2,
		"campaign_id": CAMPAIGN_ID,
		"campaign_report_resource_path": CAMPAIGN_RESOURCE_PATH,
		"campaign_validation_resource_path": CAMPAIGN_RESOURCE_PATH,
	}


static func _legacy_contract_for_report(report_path: String) -> Dictionary:
	if not report_path.is_absolute_path():
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"Legacy certification report paths must be absolute.")
	var file_result := _read_exact_file(report_path, MAX_REPORT_BYTES)
	if not bool(file_result.get("ok", false)):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"Legacy certification report is missing or unreadable.")
	var bytes: PackedByteArray = file_result["bytes"]
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"Legacy certification report is not canonical UTF-8.")
	var parser := JSON.new()
	if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return _failure(
			FailureCodesScript.JSON_PARSE_FAILED,
			"Legacy certification report must be one JSON object.")
	var dispatched: Dictionary = QualificationRegistryScript.dispatch_report(
		parser.data)
	if not bool(dispatched.get("ok", false)):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"Legacy report does not match an immutable qualification profile.",
			{
				"qualification_failure_code": String(
					dispatched.get("failure_code", "")),
				"qualification_detail": dispatched,
			})
	return {
		"ok": true,
		"contract": _legacy_contract(
			dispatched["profile"],
			String(dispatched["profile_id"])),
	}


static func _legacy_contract(
		profile: Dictionary,
		profile_id: String) -> Dictionary:
	var report: Dictionary = profile["report_contract"]
	var inventory: Dictionary = profile["inventory_contract"]
	var campaign: Dictionary = profile["campaign_contract"]
	var receipt: Dictionary = profile["receipt_contract"]
	return {
		"contract_id": profile_id,
		"qualification_profile_id": profile_id,
		"legacy_verification_only": true,
		"receipt_schema": String(receipt["schema_id"]),
		"receipt_domain": String(receipt["domain"]),
		"receipt_schema_validation_path": String(
			receipt["snapshot"]["resource_path"]),
		"receipt_directory": RECEIPT_DIRECTORY,
		"report_schema": String(report["schema_id"]),
		"report_schema_validation_path": String(
			report["snapshot"]["resource_path"]),
		"inventory_schema": String(inventory["schema_id"]),
		"inventory_id": String(inventory["inventory_id"]),
		"inventory_version": int(inventory["inventory_version"]),
		"inventory_report_resource_path": String(
			inventory["historical_resource_path"]),
		"inventory_validation_resource_path": String(
			inventory["snapshot"]["resource_path"]),
		"test_count": int(inventory["test_count"]),
		"artifact_count": int(inventory["artifact_count"]),
		"campaign_id": String(campaign["campaign_id"]),
		"campaign_report_resource_path": String(
			campaign["historical_resource_path"]),
		"campaign_validation_resource_path": String(
			campaign["snapshot"]["resource_path"]),
	}


## Test-only primitive used to prove domain separation with an authentically
## tagged wrong-domain envelope. Production APIs never accept caller keys.
static func hmac_sha256_hex_for_test(
		key: PackedByteArray,
		message: PackedByteArray) -> String:
	var result := _hmac_sha256(key, message)
	return String(result.get("hex", "")) if result["ok"] else ""


static func _attest(
		report_path: String,
		certification_id: String,
		trust_root: String,
		attested_utc: String,
		trust_mode: String,
		contract: Dictionary) -> Dictionary:
	var paths := _validate_paths(report_path, certification_id, trust_root)
	if not paths["ok"]:
		return paths
	var report_result := _inspect_report(
		String(paths["report_path"]),
		certification_id,
		contract)
	if not report_result["ok"]:
		return report_result
	var key_reference := _load_active_key_reference(String(paths["trust_root"]))
	if not key_reference["ok"]:
		return key_reference
	var timestamp := attested_utc.strip_edges()
	if timestamp.is_empty():
		timestamp = _utc_now()
	var envelope := _unsigned_envelope(
		String(key_reference["key_id"]),
		certification_id,
		report_result,
		timestamp,
		contract)
	var key_result := _load_key_by_id(
		String(paths["trust_root"]),
		String(key_reference["key_id"]))
	if not key_result["ok"]:
		return key_result
	var key := _take_loaded_key(key_result)
	var hmac_result := _hmac_sha256(
		key,
		CanonicalJsonScript.encode(envelope))
	key.fill(0)
	key.resize(0)
	if not hmac_result["ok"]:
		return hmac_result
	var receipt: Dictionary = envelope.duplicate(true)
	receipt["tag"] = "%s:%s" % [ALGORITHM, hmac_result["hex"]]
	var schema_result := SchemaValidatorScript.validate_file(
		String(contract["receipt_schema_validation_path"]),
		receipt)
	if not schema_result["ok"]:
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
			"Generated certification-report receipt failed its owned schema.",
			{"errors": schema_result["errors"]})
	var receipt_path := _receipt_path(
		String(paths["trust_root"]),
		certification_id,
		contract)
	var write_result := _write_receipt_new(receipt_path, receipt)
	if not write_result["ok"]:
		return write_result
	# Re-read the independently mutable report and installed receipt. A racing
	# report writer can only make publication fail closed.
	return _verify(
		String(paths["report_path"]),
		certification_id,
		String(paths["trust_root"]),
		trust_mode,
		contract)


static func _verify(
		report_path: String,
		certification_id: String,
		trust_root: String,
		trust_mode: String,
		contract: Dictionary) -> Dictionary:
	var paths := _validate_paths(report_path, certification_id, trust_root)
	if not paths["ok"]:
		return paths
	var report_result := _inspect_report(
		String(paths["report_path"]),
		certification_id,
		contract)
	if not report_result["ok"]:
		return report_result
	var receipt_path := _receipt_path(
		String(paths["trust_root"]),
		certification_id,
		contract)
	if not FileAccess.file_exists(receipt_path):
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_MISSING,
			"No detached certification-report receipt exists for this certification.",
			{"receipt_path": receipt_path})
	if _path_contains_link(receipt_path):
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"Certification-report receipt paths cannot traverse symbolic links or junctions.",
			{"receipt_path": receipt_path})
	var receipt_result := _read_json_object_exact(receipt_path)
	if not receipt_result["ok"]:
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
			"Detached certification-report receipt is not valid UTF-8 JSON.",
			{"receipt_path": receipt_path})
	var receipt: Dictionary = receipt_result["value"]
	var schema_result := SchemaValidatorScript.validate_file(
		String(contract["receipt_schema_validation_path"]),
		receipt)
	if not schema_result["ok"]:
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
			"Detached certification-report receipt failed its owned schema.",
			{
				"receipt_path": receipt_path,
				"errors": schema_result["errors"],
			})
	var canonical_receipt_bytes := (
		CanonicalJsonScript.stringify(receipt) + "\n").to_utf8_buffer()
	if not _constant_time_bytes_equal(
			receipt_result["bytes"],
			canonical_receipt_bytes):
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
			"Detached certification-report receipt bytes are not the one canonical encoding.",
			{"receipt_path": receipt_path})
	var expected_envelope := _unsigned_envelope(
		String(receipt["key_id"]),
		certification_id,
		report_result,
		String(receipt["attested_utc"]),
		contract)
	var recorded_envelope: Dictionary = receipt.duplicate(true)
	recorded_envelope.erase("tag")
	var recorded_envelope_bytes := CanonicalJsonScript.encode(
		recorded_envelope)
	if not _constant_time_bytes_equal(
			recorded_envelope_bytes,
			CanonicalJsonScript.encode(expected_envelope)):
		return _failure(
			FailureCodesScript.PUBLICATION_ENVELOPE_MISMATCH,
			"Receipt identity does not match the exact current certification report.",
			{"receipt_path": receipt_path})
	var key_result := _load_key_by_id(
		String(paths["trust_root"]),
		String(receipt["key_id"]))
	if not key_result["ok"]:
		return key_result
	var key := _take_loaded_key(key_result)
	var hmac_result := _hmac_sha256(key, recorded_envelope_bytes)
	key.fill(0)
	key.resize(0)
	if not hmac_result["ok"]:
		return hmac_result
	var expected_tag := "%s:%s" % [ALGORITHM, hmac_result["hex"]]
	if not _constant_time_equal(String(receipt["tag"]), expected_tag):
		return _failure(
			FailureCodesScript.PUBLICATION_TAG_MISMATCH,
			"Detached certification-report receipt authentication failed.",
			{"receipt_path": receipt_path})
	return {
		"ok": true,
		"code": "",
		"failure_code": "",
		"algorithm": ALGORITHM,
		"trust_mode": trust_mode,
		"can_promote": trust_mode == "production" \
			and not bool(contract["legacy_verification_only"]),
		"certification_contract_id": String(contract["contract_id"]),
		"qualification_profile_id":
			contract["qualification_profile_id"],
		"legacy_verification_only": bool(
			contract["legacy_verification_only"]),
		"receipt_path": receipt_path,
		"receipt_sha256": _sha256_bytes(receipt_result["bytes"]),
		"key_id": String(receipt["key_id"]),
		"certification_id": certification_id,
		"report_path": String(paths["report_path"]),
		"report_sha256": String(receipt["report_sha256"]),
		"report_bytes": int(receipt["report_bytes"]),
		"report_schema": String(receipt["report_schema"]),
		"report_status": String(receipt["report_status"]),
		"certification": String(receipt["certification"]),
		"commit_sha": String(receipt["commit_sha"]),
		"campaign_id": String(receipt["campaign_id"]),
		"campaign_sha256": String(receipt["campaign_sha256"]),
		"attested_utc": String(receipt["attested_utc"]),
	}


static func _unsigned_envelope(
		key_id: String,
		certification_id: String,
		report: Dictionary,
		attested_utc: String,
		contract: Dictionary) -> Dictionary:
	return {
		"schema": String(contract["receipt_schema"]),
		"domain": String(contract["receipt_domain"]),
		"algorithm": ALGORITHM,
		"key_id": key_id,
		"certification_id": certification_id,
		"report_name": REPORT_NAME,
		"report_sha256": String(report["report_sha256"]),
		"report_bytes": int(report["report_bytes"]),
		"report_schema": String(report["report_schema"]),
		"report_status": String(report["report_status"]),
		"certification": String(report["certification"]),
		"commit_sha": String(report["commit_sha"]),
		"campaign_id": String(report["campaign_id"]),
		"campaign_sha256": String(report["campaign_sha256"]),
		"attested_utc": attested_utc,
	}


static func _inspect_report(
		report_path: String,
		certification_id: String,
		contract: Dictionary) -> Dictionary:
	var file_result := _read_exact_file(report_path, MAX_REPORT_BYTES)
	if not file_result["ok"]:
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"Certification report is missing, unreadable, empty, or exceeds 64 MiB.")
	var bytes: PackedByteArray = file_result["bytes"]
	if (
		bytes.size() >= 3
		and bytes[0] == 0xef
		and bytes[1] == 0xbb
		and bytes[2] == 0xbf
	):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"Certification report must be UTF-8 without a byte-order mark.")
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"Certification report contains invalid or non-canonical UTF-8 bytes.")
	var parser := JSON.new()
	if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return _failure(
			FailureCodesScript.JSON_PARSE_FAILED,
			"Certification report must be one readable JSON object.")
	var report: Dictionary = parser.data
	var schema_result := SchemaValidatorScript.validate_file(
		String(contract["report_schema_validation_path"]),
		report)
	if not schema_result["ok"]:
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"Certification report failed its complete owned schema.",
			{"errors": schema_result["errors"]})
	var repository: Dictionary = report["repository"]
	var campaign: Dictionary = report["campaign"]
	var commit_sha := String(repository.get("commit_sha", ""))
	var campaign_id := String(campaign.get("campaign_id", ""))
	var campaign_sha256 := String(campaign.get("sha256", ""))
	if (
		not _is_commit_sha(commit_sha)
		or campaign_id != String(contract["campaign_id"])
		or not _is_sha256(campaign_sha256)
		or not _repository_gate_contract_is_valid(repository, commit_sha)
		or not _engine_contract_is_valid(report["engine"])
		or not _operator_self_tests_contract_is_valid(
			report["operator_self_tests"])
		or not _test_inventory_contract_is_valid(
			report["test_inventory"],
			report["engine"],
			repository,
			report["timeout_policy"],
			contract)
		or not _campaign_contract_is_valid(
			campaign,
			report["attestation"],
			report["engine"],
			contract)
		or not _report_attestation_contract_is_valid(
			report["detached_report_attestation"],
			certification_id,
			contract)
	):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"Certification report does not establish the complete fixed BR1 "
			+ "test, engine, source, campaign, final-readback, and detached "
			+ "attestation contract.")
	return {
		"ok": true,
		"report_sha256": _sha256_bytes(bytes),
		"report_bytes": bytes.size(),
		"report_schema": String(contract["report_schema"]),
		"report_status": REPORT_STATUS,
		"certification": CERTIFICATION,
		"commit_sha": commit_sha,
		"campaign_id": campaign_id,
		"campaign_sha256": campaign_sha256,
	}


static func _engine_contract_is_valid(engine: Dictionary) -> bool:
	var operator_executable := _normalized_absolute(
		String(engine.get("executable", "")))
	var physics_child_executable := _normalized_absolute(
		String(engine.get("physics_child_executable", "")))
	if (
		operator_executable.get_file() != EXPECTED_GODOT_EXECUTABLE_NAME
		or physics_child_executable.get_file()
			!= EXPECTED_PHYSICS_CHILD_EXECUTABLE_NAME
		or _path_identity(operator_executable.get_base_dir())
			!= _path_identity(physics_child_executable.get_base_dir())
		or String(engine.get("expected_version", ""))
			!= EXPECTED_GODOT_VERSION
		or String(engine.get("observed_version", ""))
			!= EXPECTED_GODOT_VERSION
		or String(engine.get("expected_executable_sha256", ""))
			!= EXPECTED_GODOT_EXECUTABLE_SHA256
		or String(engine.get("observed_executable_sha256", ""))
			!= EXPECTED_GODOT_EXECUTABLE_SHA256
		or String(engine.get("product_version", ""))
			!= EXPECTED_GODOT_PRODUCT_VERSION
		or String(engine.get("file_description", ""))
			!= EXPECTED_GODOT_FILE_DESCRIPTION
		or engine.get("exact_build_match_at_all_recorded_gates") != true
		or not _engine_identity_gates_are_valid(
			engine.get("identity_gates"),
			EXPECTED_GODOT_EXECUTABLE_SHA256,
			EXPECTED_GODOT_PRODUCT_VERSION,
			EXPECTED_GODOT_FILE_DESCRIPTION)
		or String(engine.get(
			"expected_physics_child_executable_sha256", ""))
			!= EXPECTED_PHYSICS_CHILD_EXECUTABLE_SHA256
		or String(engine.get(
			"observed_physics_child_executable_sha256", ""))
			!= EXPECTED_PHYSICS_CHILD_EXECUTABLE_SHA256
		or String(engine.get("physics_child_product_version", ""))
			!= EXPECTED_PHYSICS_CHILD_PRODUCT_VERSION
		or String(engine.get("physics_child_file_description", ""))
			!= EXPECTED_PHYSICS_CHILD_FILE_DESCRIPTION
		or engine.get(
			"physics_child_exact_build_match_at_all_recorded_gates") != true
		or not _engine_identity_gates_are_valid(
			engine.get("physics_child_identity_gates"),
			EXPECTED_PHYSICS_CHILD_EXECUTABLE_SHA256,
			EXPECTED_PHYSICS_CHILD_PRODUCT_VERSION,
			EXPECTED_PHYSICS_CHILD_FILE_DESCRIPTION)
	):
		return false

	return true


static func _engine_identity_gates_are_valid(
		gates_value: Variant,
		expected_executable_sha256: String,
		expected_product_version: String,
		expected_file_description: String) -> bool:
	const EXPECTED_STAGES: Array[String] = [
		"INITIAL",
		"AFTER_TESTS",
		"BEFORE_FINAL_SWEEP",
		"AFTER_FINAL_SWEEP",
	]
	if typeof(gates_value) != TYPE_ARRAY:
		return false
	var gates: Array = gates_value
	if gates.size() != EXPECTED_STAGES.size():
		return false
	for index in EXPECTED_STAGES.size():
		if typeof(gates[index]) != TYPE_DICTIONARY:
			return false
		var gate: Dictionary = gates[index]
		if (
			String(gate.get("stage", "")) != EXPECTED_STAGES[index]
			or String(gate.get("executable_sha256", ""))
				!= expected_executable_sha256
			or String(gate.get("product_version", ""))
				!= expected_product_version
			or String(gate.get("file_description", ""))
				!= expected_file_description
			or gate.get("matches_pinned_build") != true
		):
			return false
	return true


static func _operator_self_tests_contract_is_valid(
		operator_self_tests: Dictionary) -> bool:
	var process_runner: Dictionary = operator_self_tests.get(
		"process_runner", {})
	var initializer: Dictionary = operator_self_tests.get(
		"attestation_initializer", {})
	return (
		process_runner.get("pass") == true
		and int(process_runner.get("success_exit", -1)) == 0
		and int(process_runner.get("nonzero_exit", -1)) == 37
		and process_runner.get("timeout_detected") == true
		and process_runner.get("process_tree_killed") == true
		and process_runner.get("inherited_descendant_terminated") == true
		and process_runner.get("containment_tree_closed") == true
		and _is_sha256(String(
			process_runner.get("transcript_sha256", "")))
		and _self_test_transcript_is_valid(
			process_runner,
			[
				"PROCESS_RUNNER_SELF_TEST pass=true success_exit=0 "
					+ "timeout_detected=True process_tree_killed=True",
				"PROCESS_RUNNER_SELF_TEST nonzero_exit=37 "
					+ "inherited_descendant_terminated=True "
					+ "containment_tree_closed=True",
			])
		and initializer.get("pass") == true
		and int(initializer.get("assertions", 0)) > 0
		and initializer.get("production_store_touched") == false
		and _is_sha256(String(
			initializer.get("transcript_sha256", "")))
		and _self_test_transcript_is_valid(
			initializer,
			[
				"LAB_ATTESTATION_INITIALIZER_SELF_TEST pass=true "
					+ "assertions=%d production_store_touched=false"
					% int(initializer.get("assertions", 0)),
			])
	)


static func _self_test_transcript_is_valid(
		witness: Dictionary,
		required_lines: Array) -> bool:
	var transcript := _read_file_allow_empty(
		_normalized_absolute(String(witness.get("transcript_path", ""))),
		MAX_REPORT_BYTES)
	if (
		not transcript["ok"]
		or _sha256_bytes(transcript["bytes"])
			!= String(witness.get("transcript_sha256", ""))
	):
		return false
	var bytes: PackedByteArray = transcript["bytes"]
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return false
	for required_line_value in required_lines:
		var required_line := String(required_line_value)
		var regex := RegEx.new()
		if (
			regex.compile(
				"(?m)^%s\\s*$" % required_line.replace(
					"\\", "\\\\").replace(".", "\\.")) != OK
			or regex.search(text) == null
		):
			return false
	return true


static func _test_inventory_contract_is_valid(
		inventory: Dictionary,
		engine: Dictionary,
		repository: Dictionary,
		timeout_policy: Dictionary,
		contract: Dictionary) -> bool:
	var inventory_report_path := String(
		contract["inventory_report_resource_path"])
	var inventory_validation_path := String(
		contract["inventory_validation_resource_path"])
	var pinned_test_count := int(contract["test_count"])
	var expected_path := _normalized_absolute(
		ProjectSettings.globalize_path(inventory_report_path))
	if (
		expected_path.is_empty()
		or _path_identity(String(inventory.get("path", "")))
			!= _path_identity(expected_path)
		or String(inventory.get("sha256", ""))
			!= _resource_sha256(inventory_validation_path)
		or int(inventory.get("required", -1)) != pinned_test_count
		or int(inventory.get("executed", -1)) != pinned_test_count
		or int(inventory.get("passed", -1)) != pinned_test_count
		or int(inventory.get("failed", -1)) != 0
		or int(inventory.get("missing", -1)) != 0
		or int(inventory.get("extra", -1)) != 0
	):
		return false
	var inventory_result := _read_resource_json_object(
		inventory_validation_path)
	if not inventory_result["ok"]:
		return false
	var owned_inventory: Dictionary = inventory_result["value"]
	var tests_value: Variant = owned_inventory.get("tests")
	if (
		String(owned_inventory.get("schema", ""))
			!= String(contract["inventory_schema"])
		or String(owned_inventory.get("inventory_id", ""))
			!= String(contract["inventory_id"])
		or int(owned_inventory.get("inventory_version", -1))
			!= int(contract["inventory_version"])
		or int(owned_inventory.get("test_count", -1)) != pinned_test_count
		or typeof(tests_value) != TYPE_ARRAY
	):
		return false
	var tests: Array = tests_value
	var unique_tests: Dictionary = {}
	for test_value in tests:
		var test_name := String(test_value)
		if (
			not test_name.begins_with("test_lab_")
			or not test_name.ends_with(".gd")
			or unique_tests.has(test_name)
		):
			return false
		unique_tests[test_name] = true
	if tests.size() != pinned_test_count \
			or unique_tests.size() != pinned_test_count:
		return false
	var payload_base64 := String(
		inventory.get("report_payload_base64", ""))
	if payload_base64.length() % 4 != 0:
		return false
	var report_bytes := Marshalls.base64_to_raw(payload_base64)
	if (
		report_bytes.is_empty()
		or Marshalls.raw_to_base64(report_bytes) != payload_base64
		or report_bytes.size() != int(inventory.get("report_bytes", -1))
		or _sha256_bytes(report_bytes)
			!= String(inventory.get("report_sha256", ""))
	):
		return false
	var report_path := _normalized_absolute(
		String(inventory.get("report_path", "")))
	var current_report := _read_file_allow_empty(
		report_path,
		MAX_REPORT_BYTES)
	if (
		not current_report["ok"]
		or not _constant_time_bytes_equal(
			report_bytes,
			current_report["bytes"])
	):
		return false
	var report_text := report_bytes.get_string_from_utf8()
	if report_text.to_utf8_buffer() != report_bytes:
		return false
	var report_parser := JSON.new()
	if (
		report_parser.parse(report_text) != OK
		or typeof(report_parser.data) != TYPE_DICTIONARY
	):
		return false
	var artifacts_value: Variant = inventory.get("artifacts")
	if typeof(artifacts_value) != TYPE_ARRAY:
		return false
	var production_store: Dictionary = inventory.get(
		"production_trust_store", {})
	if (
		production_store.get("unchanged") != true
		or String(production_store.get("before_sha256", ""))
			!= String(production_store.get("after_sha256", ""))
	):
		return false
	return _test_report_payload_is_valid(
		report_parser.data,
		tests,
		artifacts_value,
		engine,
		repository,
		timeout_policy,
		contract)


static func _test_report_payload_is_valid(
		test_report: Dictionary,
		expected_tests: Array,
		artifacts: Array,
		engine: Dictionary,
		repository: Dictionary,
		timeout_policy: Dictionary,
		contract: Dictionary) -> bool:
	var pinned_test_count := int(contract["test_count"])
	var pinned_artifact_count := int(contract["artifact_count"])
	var results_value: Variant = test_report.get("results")
	if (
		String(test_report.get("schema", ""))
			!= "sporespore.lab.test_report.v1"
		or String(test_report.get("pattern", "")) != "test_lab_*.gd"
		or int(test_report.get("total", -1)) != pinned_test_count
		or int(test_report.get("passed", -1)) != pinned_test_count
		or int(test_report.get("failed", -1)) != 0
		or int(test_report.get("test_timeout_seconds", -1))
			!= int(timeout_policy.get("per_test_seconds", -2))
		or _path_identity(String(test_report.get("godot", "")))
			!= _path_identity(String(engine.get("executable", "")))
		or _path_identity(String(test_report.get("repository", "")))
			!= _path_identity(String(repository.get("root", "")))
		or typeof(results_value) != TYPE_ARRAY
		or artifacts.size() != pinned_artifact_count
	):
		return false
	var results: Array = results_value
	if results.size() != pinned_test_count:
		return false
	var artifact_map: Dictionary = {}
	for artifact_value in artifacts:
		if typeof(artifact_value) != TYPE_DICTIONARY:
			return false
		var artifact: Dictionary = artifact_value
		var test_name := String(artifact.get("test", ""))
		var kind := String(artifact.get("kind", ""))
		var key := "%s:%s" % [test_name, kind]
		var artifact_path := _normalized_absolute(
			String(artifact.get("path", "")))
		var artifact_file := _read_file_allow_empty(
			artifact_path,
			MAX_REPORT_BYTES)
		if (
			artifact_map.has(key)
			or not test_name in expected_tests
			or not kind in ["engine_log", "transcript_log"]
			or not artifact_file["ok"]
			or int(artifact.get("bytes", -1))
				!= int(artifact_file["bytes"].size())
			or String(artifact.get("sha256", ""))
				!= _sha256_bytes(artifact_file["bytes"])
		):
			return false
		artifact_map[key] = artifact
	for index in pinned_test_count:
		if typeof(results[index]) != TYPE_DICTIONARY:
			return false
		var result: Dictionary = results[index]
		var expected_name := String(expected_tests[index])
		var engine_key := "%s:engine_log" % expected_name
		var transcript_key := "%s:transcript_log" % expected_name
		var engine_artifact: Dictionary = artifact_map.get(engine_key, {})
		var transcript_artifact: Dictionary = artifact_map.get(
			transcript_key, {})
		if (
			String(result.get("test", "")) != expected_name
			or String(result.get("status", "")) != "pass"
			or int(result.get("process_exit_code", -1)) != 0
			or result.get("timed_out") != false
			or result.get("containment_tree_closed") != true
			or result.get("exit_marker_observed") != true
			or not String(result.get("process_start_error", "")).is_empty()
			or not String(
				result.get("process_termination_error", "")).is_empty()
			or result.get("footer_found") != true
			or int(result.get("footer_count", -1)) != 1
			or int(result.get("assertions_passed", 0)) <= 0
			or int(result.get("assertions_failed", -1)) != 0
			or result.get("engine_log_exists") != true
			or result.get("engine_log_readable") != true
			or result.get("transcript_log_exists") != true
			or result.get("transcript_log_readable") != true
			or typeof(result.get("unexpected_engine_errors")) != TYPE_ARRAY
			or not result["unexpected_engine_errors"].is_empty()
			or typeof(
				result.get("missing_expected_engine_error_codes"))
				!= TYPE_ARRAY
			or not result[
				"missing_expected_engine_error_codes"].is_empty()
			or typeof(
				result.get("unknown_expected_engine_error_codes"))
				!= TYPE_ARRAY
			or not result[
				"unknown_expected_engine_error_codes"].is_empty()
			or not artifact_map.has(engine_key)
			or not artifact_map.has(transcript_key)
			or _path_identity(String(result.get("engine_log", "")))
				!= _path_identity(String(engine_artifact.get("path", "")))
			or _path_identity(String(result.get("transcript_log", "")))
				!= _path_identity(String(
					transcript_artifact.get("path", "")))
			or String(result.get("engine_log_sha256", ""))
				!= String(engine_artifact.get("sha256", ""))
			or String(result.get("transcript_log_sha256", ""))
				!= String(transcript_artifact.get("sha256", ""))
			or int(result.get("engine_log_bytes", -1))
				!= int(engine_artifact.get("bytes", -2))
			or int(result.get("transcript_log_bytes", -1))
				!= int(transcript_artifact.get("bytes", -2))
		):
			return false
	return artifact_map.size() == pinned_artifact_count


static func _campaign_contract_is_valid(
		campaign: Dictionary,
		bundle_attestation: Dictionary,
		engine: Dictionary,
		contract: Dictionary) -> bool:
	var campaign_report_path := String(
		contract["campaign_report_resource_path"])
	var campaign_validation_path := String(
		contract["campaign_validation_resource_path"])
	var expected_path := _normalized_absolute(
		ProjectSettings.globalize_path(campaign_report_path))
	if (
		expected_path.is_empty()
		or _path_identity(String(campaign.get("path", "")))
			!= _path_identity(expected_path)
		or String(campaign.get("sha256", ""))
			!= _resource_sha256(campaign_validation_path)
	):
		return false
	var catalog_result := _read_resource_json_object(
		campaign_validation_path)
	if not catalog_result["ok"]:
		return false
	var catalog: Dictionary = catalog_result["value"]
	var catalog_cells_value: Variant = catalog.get("cells")
	var report_cells_value: Variant = campaign.get("cells")
	if (
		String(catalog.get("schema", ""))
			!= "sporespore.lab.br1_l0_certification_campaign.v1"
		or String(catalog.get("campaign_id", "")) \
			!= String(contract["campaign_id"])
		or int(catalog.get("campaign_version", -1)) != 1
		or int(catalog.get("cell_count", -1)) != 7
		or typeof(catalog_cells_value) != TYPE_ARRAY
		or typeof(report_cells_value) != TYPE_ARRAY
	):
		return false
	var catalog_cells: Array = catalog_cells_value
	var report_cells: Array = report_cells_value
	if catalog_cells.size() != 7 or report_cells.size() != 7:
		return false
	var outer_parent_ids: Dictionary = {}
	var physics_child_ids: Dictionary = {}
	var reservation_ids: Dictionary = {}
	var run_ids: Dictionary = {}
	var bundle_paths: Dictionary = {}
	var receipt_paths: Dictionary = {}
	var recomputed_pid_recycles: Array = []
	var report_key_id := String(bundle_attestation.get("key_id", ""))
	var physics_child_engine_path := String(
		engine.get("physics_child_executable", ""))
	for cell_index in 7:
		if (
			typeof(catalog_cells[cell_index]) != TYPE_DICTIONARY
			or typeof(report_cells[cell_index]) != TYPE_DICTIONARY
		):
			return false
		var catalog_cell: Dictionary = catalog_cells[cell_index]
		var report_cell: Dictionary = report_cells[cell_index]
		var seed_policy: Dictionary = catalog_cell.get("seed_policy", {})
		var observer: Dictionary = catalog_cell.get("observer", {})
		var resource_path := String(catalog_cell.get("resource_path", ""))
		if (
			String(report_cell.get("cell_id", ""))
				!= String(catalog_cell.get("cell_id", ""))
			or String(report_cell.get("resource_path", "")) != resource_path
			or String(report_cell.get("resource_sha256", ""))
				!= _resource_sha256(resource_path)
			or int(report_cell.get("root_seed", 0))
				!= int(seed_policy.get("root_seed", -1))
			or String(report_cell.get("observer_adapter", ""))
				!= String(observer.get("adapter_id", ""))
			or String(report_cell.get("observer_profile", ""))
				!= String(observer.get("primary_profile_id", ""))
			or not _cell_witness_contract_is_valid(
				report_cell,
				report_key_id,
				physics_child_engine_path,
				outer_parent_ids,
				physics_child_ids,
				reservation_ids,
				run_ids,
				bundle_paths,
				receipt_paths,
				recomputed_pid_recycles)
		):
			return false
	return (
		_ledger_invocation_total(outer_parent_ids) == 14
		and _ledger_invocation_total(physics_child_ids) == 14
		and reservation_ids.size() == 14
		and run_ids.size() == 14
		and bundle_paths.size() == 14
		and receipt_paths.size() == 14
		and _recycle_witnesses_match(
			campaign.get("pid_recycle_events"),
			recomputed_pid_recycles)
	)


static func _cell_witness_contract_is_valid(
		cell: Dictionary,
		report_key_id: String,
		physics_child_engine_path: String,
		outer_parent_ids: Dictionary,
		physics_child_ids: Dictionary,
		reservation_ids: Dictionary,
		run_ids: Dictionary,
		bundle_paths: Dictionary,
		receipt_paths: Dictionary,
		recomputed_pid_recycles: Array) -> bool:
	var replicates_value: Variant = cell.get("replicates")
	if typeof(replicates_value) != TYPE_ARRAY:
		return false
	var replicates: Array = replicates_value
	if replicates.size() != 2:
		return false
	for replicate_index in 2:
		if typeof(replicates[replicate_index]) != TYPE_DICTIONARY:
			return false
		if not _replicate_witness_contract_is_valid(
				replicates[replicate_index],
				replicate_index + 1,
				report_key_id,
				physics_child_engine_path,
				outer_parent_ids,
				physics_child_ids,
				reservation_ids,
				run_ids,
				bundle_paths,
				receipt_paths,
				recomputed_pid_recycles):
			return false
	var comparison: Dictionary = cell.get("comparison", {})
	var final_comparison: Dictionary = cell.get("final_comparison", {})
	return (
		comparison.get("pass") == true
		and final_comparison.get("pass") == true
		and int(comparison.get("mismatch_count", -1)) == 0
		and int(final_comparison.get("mismatch_count", -1)) == 0
		and String(comparison.get("left_evidence_digest", ""))
			== String(comparison.get("right_evidence_digest", ""))
		and String(final_comparison.get("left_evidence_digest", ""))
			== String(final_comparison.get("right_evidence_digest", ""))
		and String(final_comparison.get("comparator_id", ""))
			== String(comparison.get("comparator_id", ""))
		and String(final_comparison.get("result_sha256", ""))
			== String(comparison.get("result_sha256", ""))
		and String(final_comparison.get("left_evidence_digest", ""))
			== String(comparison.get("left_evidence_digest", ""))
		and String(final_comparison.get("right_evidence_digest", ""))
			== String(comparison.get("right_evidence_digest", ""))
	)


static func _replicate_witness_contract_is_valid(
		replicate: Dictionary,
		expected_replicate: int,
		report_key_id: String,
		physics_child_engine_path: String,
		outer_parent_ids: Dictionary,
		physics_child_ids: Dictionary,
		reservation_ids: Dictionary,
		run_ids: Dictionary,
		bundle_paths: Dictionary,
		receipt_paths: Dictionary,
		recomputed_pid_recycles: Array) -> bool:
	var run_id := String(replicate.get("run_id", ""))
	var bundle_path := _path_identity(String(replicate.get("bundle_path", "")))
	var attestation: Dictionary = replicate.get("attestation", {})
	var process: Dictionary = replicate.get("process_identity", {})
	var validation: Dictionary = replicate.get("independent_validation", {})
	var publication: Dictionary = validation.get(
		"publication_attestation", {})
	var replay: Dictionary = replicate.get("replay", {})
	var final_sweep: Dictionary = replicate.get("final_sweep", {})
	var final_process: Dictionary = final_sweep.get("process_identity", {})
	var final_validation: Dictionary = final_sweep.get("validation", {})
	var final_publication: Dictionary = final_validation.get(
		"publication_attestation", {})
	var final_replay: Dictionary = final_sweep.get("replay", {})
	var receipt_path := _path_identity(
		String(attestation.get("receipt_path", "")))
	var outer_parent_id := int(process.get("outer_parent_process_id", 0))
	var physics_child_id := int(process.get("physics_child_process_id", 0))
	var reservation_id := String(process.get("reservation_id", ""))
	if (
		int(replicate.get("replicate", 0)) != expected_replicate
		or run_id.is_empty()
		or bundle_path.is_empty()
		or receipt_path.is_empty()
		or outer_parent_id <= 0
		or physics_child_id <= 0
		or outer_parent_id == physics_child_id
		or int(process.get("termination_observer_process_id", 0))
			!= outer_parent_id
		or _path_identity(String(process.get("executable", "")))
			!= _path_identity(physics_child_engine_path)
		or String(attestation.get("key_id", "")) != report_key_id
		or String(attestation.get("trust_mode", "")) != "production"
		or attestation.get("valid") != true
		or validation.get("can_finalize") != true
		or validation.get("can_promote") != true
		or String(publication.get("key_id", "")) != report_key_id
		or String(publication.get("run_id", "")) != run_id
		or String(publication.get("trust_mode", "")) != "production"
		or publication.get("valid") != true
		or replay.get("pass") != true
		or int(replay.get("simulation_steps", -1)) != 0
		or final_sweep.get("pass") != true
		or final_sweep.get("retained_witness_match") != true
		or final_sweep.get("production_attestation_required") != true
		or final_sweep.get("promotion_required") != true
		or final_process != process
		or String(final_publication.get("key_id", "")) != report_key_id
		or String(final_publication.get("run_id", "")) != run_id
		or String(final_publication.get("receipt_sha256", ""))
			!= String(attestation.get("receipt_sha256", ""))
		or _path_identity(String(final_publication.get("receipt_path", "")))
			!= receipt_path
		or final_replay.get("pass") != true
		or int(final_replay.get("simulation_steps", -1)) != 0
		or int(final_replay.get("frames", -1))
			!= int(replay.get("frames", -2))
		or int(final_replay.get("events", -1))
			!= int(replay.get("events", -2))
		or String(final_sweep.get("manifest_sha256", ""))
			!= String(replicate.get("bundle_manifest_sha256", ""))
		or String(final_sweep.get("checksums_sha256", ""))
			!= String(replicate.get("bundle_checksums_sha256", ""))
		or String(final_sweep.get("summary_sha256", ""))
			!= String(replicate.get("bundle_summary_sha256", ""))
		or String(final_sweep.get("process_metadata_sha256", ""))
			!= String(replicate.get("process_metadata_sha256", ""))
		or String(final_sweep.get("launch_plan_sha256", ""))
			!= String(replicate.get("launch_plan_sha256", ""))
		or String(final_sweep.get("receipt_sha256", ""))
			!= String(attestation.get("receipt_sha256", ""))
		or _path_identity(String(final_sweep.get("receipt_path", "")))
			!= receipt_path
		or reservation_ids.has(reservation_id)
		or run_ids.has(run_id)
		or bundle_paths.has(bundle_path)
		or receipt_paths.has(receipt_path)
	):
		return false
	var started_utc := String(process.get("started_utc", ""))
	var ended_utc := String(process.get("ended_utc", ""))
	if not _register_process_invocation(
			outer_parent_ids,
			"outer_parent",
			outer_parent_id,
			run_id,
			started_utc,
			ended_utc,
			recomputed_pid_recycles):
		return false
	if not _register_process_invocation(
			physics_child_ids,
			"physics_child",
			physics_child_id,
			run_id,
			started_utc,
			ended_utc,
			recomputed_pid_recycles):
		return false
	reservation_ids[reservation_id] = true
	run_ids[run_id] = true
	bundle_paths[bundle_path] = true
	receipt_paths[receipt_path] = true
	return true


static func _parse_utc_instant(value: String) -> Dictionary:
	var matcher := RegEx.new()
	if matcher.compile(
			"^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})"
			+ "(\\.[0-9]+)?Z$") != OK:
		return {"ok": false}
	var found := matcher.search(value)
	if found == null:
		return {"ok": false}
	var fraction := 0.0
	var fraction_text := found.get_string(2)
	if not fraction_text.is_empty():
		fraction = ("0" + fraction_text).to_float()
	return {
		"ok": true,
		"seconds": int(Time.get_unix_time_from_datetime_string(
			found.get_string(1))),
		"fraction": fraction,
	}


static func _instant_not_after(left: Dictionary, right: Dictionary) -> bool:
	if int(left["seconds"]) != int(right["seconds"]):
		return int(left["seconds"]) < int(right["seconds"])
	return float(left["fraction"]) <= float(right["fraction"])


static func _register_process_invocation(
		ledger: Dictionary,
		role: String,
		process_id: int,
		run_id: String,
		started_utc: String,
		ended_utc: String,
		recomputed_recycles: Array) -> bool:
	var started := _parse_utc_instant(started_utc)
	var ended := _parse_utc_instant(ended_utc)
	if not bool(started.get("ok", false)) or not bool(ended.get("ok", false)):
		return false
	if not _instant_not_after(started, ended):
		return false
	var key := str(process_id)
	if not ledger.has(key):
		ledger[key] = []
	var entries: Array = ledger[key]
	for prior_value in entries:
		var prior: Dictionary = prior_value
		if String(prior["run_id"]) == run_id:
			return false
		# Windows recycles PIDs across non-overlapping lifetimes, so PID
		# equality is process identity only when the sealed run windows
		# overlap. An overlap means two live runs claimed one process and
		# fails closed. A disjoint recycle is legal, but the operator must
		# have declared it as a pid_recycle_events witness; the declared
		# list is recomputed here and compared exactly.
		var prior_is_earlier := _instant_not_after(prior["ended"], started)
		var replicate_is_earlier := _instant_not_after(
			ended, prior["started"])
		if not prior_is_earlier and not replicate_is_earlier:
			return false
		recomputed_recycles.append({
			"role": role,
			"process_id": process_id,
			"earlier_run_id": (
				String(prior["run_id"]) if prior_is_earlier else run_id),
			"earlier_ended_utc": (
				String(prior["ended_utc"])
				if prior_is_earlier
				else ended_utc),
			"later_run_id": (
				run_id if prior_is_earlier else String(prior["run_id"])),
			"later_started_utc": (
				started_utc
				if prior_is_earlier
				else String(prior["started_utc"])),
		})
	entries.append({
		"run_id": run_id,
		"started": started,
		"ended": ended,
		"started_utc": started_utc,
		"ended_utc": ended_utc,
	})
	return true


static func _ledger_invocation_total(ledger: Dictionary) -> int:
	var total := 0
	for entries_value in ledger.values():
		if typeof(entries_value) != TYPE_ARRAY:
			return -1
		total += (entries_value as Array).size()
	return total


static func _recycle_witnesses_match(
		reported_value: Variant,
		recomputed: Array) -> bool:
	if typeof(reported_value) != TYPE_ARRAY:
		return false
	var reported: Array = reported_value
	if reported.size() != recomputed.size():
		return false
	for index in reported.size():
		if typeof(reported[index]) != TYPE_DICTIONARY:
			return false
		var left: Dictionary = reported[index]
		var right: Dictionary = recomputed[index]
		if (
			left.size() != right.size()
			or String(left.get("role", "")) != String(right["role"])
			or int(left.get("process_id", -1)) != int(right["process_id"])
			or String(left.get("earlier_run_id", ""))
				!= String(right["earlier_run_id"])
			or String(left.get("earlier_ended_utc", ""))
				!= String(right["earlier_ended_utc"])
			or String(left.get("later_run_id", ""))
				!= String(right["later_run_id"])
			or String(left.get("later_started_utc", ""))
				!= String(right["later_started_utc"])
		):
			return false
	return true


static func _report_attestation_contract_is_valid(
		policy: Dictionary,
		certification_id: String,
		contract: Dictionary) -> bool:
	return (
		_is_safe_certification_id(certification_id)
		and String(policy.get("certification_id", "")) == certification_id
		and policy.get("required") == true
		and policy.get("report_rewrite_after_attestation_forbidden") == true
		and String(policy.get("timing", ""))
			== "after_complete_report_serialization"
		and String(policy.get("cli_resource", ""))
			== "res://scripts/lab/certification_report_attestation_cli.gd"
		and String(policy.get("receipt_schema", "")) \
			== String(contract["receipt_schema"])
		and String(policy.get("algorithm", "")) == ALGORITHM
		and String(policy.get("trust_mode", "")) == "production"
	)


static func _repository_gate_contract_is_valid(
		repository: Dictionary,
		commit_sha: String) -> bool:
	const TEMPORAL_CLAIM := (
		"Cleanliness and commit identity were observed at the listed gates; "
		+ "this does not claim continuous monitoring between gates.")
	const EXPECTED_STAGES: Array[String] = [
		"INITIAL",
		"AFTER_TESTS",
		"BEFORE_FINAL_SWEEP",
		"AFTER_FINAL_SWEEP",
	]
	if (
		repository.get("clean_at_all_recorded_gates") != true
		or repository.get("commit_unchanged_at_all_recorded_gates") != true
		or String(repository.get("temporal_claim", "")) != TEMPORAL_CLAIM
		or typeof(repository.get("gates")) != TYPE_ARRAY
	):
		return false
	var repository_root := String(repository.get("root", "")).strip_edges()
	if repository_root.is_empty():
		return false
	var gates: Array = repository["gates"]
	if gates.size() != EXPECTED_STAGES.size():
		return false
	for index in EXPECTED_STAGES.size():
		if typeof(gates[index]) != TYPE_DICTIONARY:
			return false
		var gate: Dictionary = gates[index]
		if (
			gate.size() != 4
			or gate.get("clean") != true
			or String(gate.get("commit_sha", "")) != commit_sha
			# Git reports the worktree root with forward slashes while the
			# operator records its native path, so root identity must be
			# compared as a normalized path, not as raw bytes.
			or _path_identity(String(gate.get("repository_root", "")))
				!= _path_identity(repository_root)
			or String(gate.get("checked_stage", ""))
				!= EXPECTED_STAGES[index]
		):
			return false
	return true


static func _validate_paths(
		report_path: String,
		certification_id: String,
		trust_root: String) -> Dictionary:
	if not _is_safe_certification_id(certification_id):
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"certification_id must be a safe, non-path identity of at most 160 characters.")
	var report := _normalized_absolute(report_path)
	var trust := _normalized_absolute(trust_root)
	var project_root := _normalized_absolute(
		ProjectSettings.globalize_path("res://"))
	if report.is_empty() or trust.is_empty():
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"Report and trust-root paths must resolve to absolute paths.")
	if report.get_file() != REPORT_NAME:
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"Certification report filename must be exactly %s." % REPORT_NAME)
	if not FileAccess.file_exists(report):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"Certification report path is not an existing file.")
	if _paths_overlap(report, trust):
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"The detached trust root must not contain or be contained by the report path.")
	if (
		trust == project_root
		or _is_descendant(trust, project_root)
		or report == project_root
		or _is_descendant(report, project_root)
	):
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"Certification report and detached trust material must remain outside the repository.")
	if _path_contains_link(report) or _path_contains_link(trust):
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"Report and trust-root paths cannot traverse symbolic links or junctions.")
	return {
		"ok": true,
		"report_path": report,
		"trust_root": trust,
	}


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


static func _load_active_key_reference(trust_root: String) -> Dictionary:
	var pointer_path := trust_root.path_join(ACTIVE_KEY_FILE)
	if _path_contains_link(pointer_path):
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"Active-key paths cannot traverse symbolic links or junctions.")
	var pointer_result := _read_json_object_exact(pointer_path)
	if not pointer_result["ok"]:
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_MISSING,
			"The attestation trust root has no readable active_key.json pointer.")
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
	if _path_contains_link(key_path):
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"Key paths cannot traverse symbolic links or junctions.")
	var file := FileAccess.open(key_path, FileAccess.READ)
	if file == null:
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_MISSING,
			"The receipt's keyed identity is not present in the trust root.")
	if file.get_length() != KEY_BYTES:
		file.close()
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_INVALID,
			"Certification-report HMAC keys must be exactly 32 raw bytes.")
	var key := file.get_buffer(KEY_BYTES)
	file.close()
	if key.size() != KEY_BYTES:
		key.fill(0)
		key.resize(0)
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_INVALID,
			"Certification-report HMAC key read was truncated.")
	var observed_id := _sha256_bytes(key)
	if not _constant_time_equal(observed_id, key_id):
		key.fill(0)
		key.resize(0)
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_INVALID,
			"Certification-report HMAC key bytes do not match their key_id.")
	return {
		"ok": true,
		"key": key,
		"key_id": observed_id,
	}


static func _take_loaded_key(key_result: Dictionary) -> PackedByteArray:
	var key: PackedByteArray = key_result.get("key", PackedByteArray())
	key_result["key"] = PackedByteArray()
	return key


static func _write_receipt_new(path: String, receipt: Dictionary) -> Dictionary:
	var parent := path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(parent)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_WRITE_FAILED,
			"Could not create the certification-report receipt directory.")
	if _path_contains_link(parent):
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"Receipt paths cannot traverse symbolic links or junctions.")
	if _path_entry_exists(path):
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_COLLISION,
			"A certification-report receipt already exists; receipts are append-only.",
			{"receipt_path": path})
	var reservation := "%s.attestation-lock" % path
	var reservation_error := DirAccess.make_dir_absolute(reservation)
	if reservation_error != OK:
		if _path_entry_exists(path):
			return _failure(
				FailureCodesScript.PUBLICATION_RECEIPT_COLLISION,
				"A certification-report receipt already exists; receipts are append-only.",
				{"receipt_path": path})
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_BUSY,
			"Another report attester owns this receipt path, or a prior crash left its lock.",
			{"receipt_path": path})
	if _path_entry_exists(path):
		DirAccess.remove_absolute(reservation)
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_COLLISION,
			"A certification-report receipt already exists; receipts are append-only.",
			{"receipt_path": path})
	var temporary := reservation.path_join(
		"receipt-%d-%d.tmp" % [OS.get_process_id(), Time.get_ticks_usec()])
	var serialized := CanonicalJsonScript.stringify(receipt) + "\n"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		DirAccess.remove_absolute(reservation)
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_WRITE_FAILED,
			"Could not open the certification-report receipt temporary file.")
	file.store_string(serialized)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		DirAccess.remove_absolute(reservation)
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_WRITE_FAILED,
			"Could not flush the certification-report receipt temporary file.")
	if _path_entry_exists(path):
		DirAccess.remove_absolute(temporary)
		DirAccess.remove_absolute(reservation)
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_COLLISION,
			"A certification-report receipt already exists; receipts are append-only.",
			{"receipt_path": path})
	var rename_error := DirAccess.rename_absolute(temporary, path)
	if rename_error != OK:
		DirAccess.remove_absolute(temporary)
		DirAccess.remove_absolute(reservation)
		if _path_entry_exists(path):
			return _failure(
				FailureCodesScript.PUBLICATION_RECEIPT_COLLISION,
				"A detached certification-report receipt won the publication race.",
				{"receipt_path": path})
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_WRITE_FAILED,
			"Could not install the certification-report receipt.",
			{"error": error_string(rename_error)})
	var installed_matches := FileAccess.get_file_as_string(path) == serialized
	DirAccess.remove_absolute(reservation)
	if not installed_matches:
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_WRITE_FAILED,
			"Installed certification-report receipt bytes differ from the canonical payload.")
	return {"ok": true}


static func _read_exact_file(path: String, maximum_bytes: int) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false}
	var length := file.get_length()
	if length < 1 or length > maximum_bytes:
		file.close()
		return {"ok": false}
	var bytes := file.get_buffer(length)
	var error := file.get_error()
	file.close()
	if error != OK or bytes.size() != length:
		return {"ok": false}
	return {
		"ok": true,
		"bytes": bytes,
	}


static func _read_file_allow_empty(
		path: String,
		maximum_bytes: int) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false}
	var length := file.get_length()
	if length < 0 or length > maximum_bytes:
		file.close()
		return {"ok": false}
	var bytes := file.get_buffer(length) if length > 0 else PackedByteArray()
	var error := file.get_error()
	file.close()
	if error != OK or bytes.size() != length:
		return {"ok": false}
	return {
		"ok": true,
		"bytes": bytes,
	}


static func _read_json_object_exact(path: String) -> Dictionary:
	var file_result := _read_exact_file(path, MAX_REPORT_BYTES)
	if not file_result["ok"]:
		return {"ok": false}
	var bytes: PackedByteArray = file_result["bytes"]
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return {"ok": false}
	var parser := JSON.new()
	if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {"ok": false}
	return {
		"ok": true,
		"value": parser.data,
		"bytes": bytes,
	}


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
	return _constant_time_bytes_equal(
		left.to_utf8_buffer(),
		right.to_utf8_buffer())


static func _constant_time_bytes_equal(
		left: PackedByteArray,
		right: PackedByteArray) -> bool:
	var difference := left.size() ^ right.size()
	var length := maxi(left.size(), right.size())
	for index in length:
		var left_byte := int(left[index]) if index < left.size() else 0
		var right_byte := int(right[index]) if index < right.size() else 0
		difference = difference | (left_byte ^ right_byte)
	return difference == 0


static func _path_contains_link(path: String) -> bool:
	var cursor := _normalized_absolute(path)
	if cursor.is_empty():
		return true
	var windows_root := RegEx.new()
	windows_root.compile("^[A-Za-z]:/?$")
	while true:
		if cursor == "/" or windows_root.search(cursor) != null:
			return false
		var parent := cursor.get_base_dir()
		if parent.is_empty() or parent == cursor:
			return false
		var leaf := cursor.get_file()
		var directory := DirAccess.open(parent)
		if directory != null and directory.is_link(leaf):
			return true
		cursor = parent
	return false


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


static func _path_entry_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)


static func _resource_sha256(resource_path: String) -> String:
	if not resource_path.begins_with("res://"):
		return ""
	var absolute_path := _normalized_absolute(
		ProjectSettings.globalize_path(resource_path))
	if absolute_path.is_empty() or not FileAccess.file_exists(absolute_path):
		return ""
	var digest := FileAccess.get_sha256(absolute_path).to_lower()
	return "sha256:%s" % digest if digest.length() == 64 else ""


static func _read_resource_json_object(resource_path: String) -> Dictionary:
	if not resource_path.begins_with("res://"):
		return {"ok": false}
	var file_result := _read_exact_file(
		ProjectSettings.globalize_path(resource_path),
		MAX_REPORT_BYTES)
	if not file_result["ok"]:
		return {"ok": false}
	var bytes: PackedByteArray = file_result["bytes"]
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return {"ok": false}
	var parser := JSON.new()
	if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {"ok": false}
	return {
		"ok": true,
		"value": parser.data,
	}


static func _sha256_bytes(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if not bytes.is_empty() and context.update(bytes) != OK:
		context.finish()
		return ""
	return "sha256:%s" % context.finish().hex_encode()


static func _is_safe_certification_id(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9][A-Za-z0-9._-]{0,159}$")
	return regex.search(value) != null


static func _is_commit_sha(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[a-f0-9]{40}$")
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
