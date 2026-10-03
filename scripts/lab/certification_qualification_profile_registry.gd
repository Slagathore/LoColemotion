class_name LabCertificationQualificationProfileRegistry
extends RefCounted
# gdlint: disable=max-line-length

## Fail-closed selection and loading for the two historical BR1 report-v1
## qualification profiles.
##
## This registry is intentionally separate from the current v1 attester. It is
## append-only groundwork for a compatibility dispatcher: no call here creates
## a receipt, chooses a path supplied by a report, or weakens either historical
## schema. A profile loads only when its own bytes, its schema bytes, and every
## referenced snapshot match the source-controlled allowlist exactly.

const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")

const PROFILE_R001_I45 := "BR1_L0_V1_R001_I45"
const PROFILE_R002_I51 := "BR1_L0_V1_R002_I51"

const FAILURE_PROFILE_UNKNOWN := "CERTIFICATION_QUALIFICATION_PROFILE_UNKNOWN"
const FAILURE_DISPATCH_IDENTITY_INVALID := "CERTIFICATION_QUALIFICATION_DISPATCH_IDENTITY_INVALID"
const FAILURE_PROFILE_FILE_MISSING := "CERTIFICATION_QUALIFICATION_PROFILE_FILE_MISSING"
const FAILURE_PROFILE_HASH_MISMATCH := "CERTIFICATION_QUALIFICATION_PROFILE_HASH_MISMATCH"
const FAILURE_PROFILE_SCHEMA_HASH_MISMATCH := "CERTIFICATION_QUALIFICATION_PROFILE_SCHEMA_HASH_MISMATCH"
const FAILURE_PROFILE_INVALID := "CERTIFICATION_QUALIFICATION_PROFILE_INVALID"
const FAILURE_SNAPSHOT_NOT_ALLOWLISTED := "CERTIFICATION_QUALIFICATION_SNAPSHOT_NOT_ALLOWLISTED"
const FAILURE_SNAPSHOT_FILE_MISSING := "CERTIFICATION_QUALIFICATION_SNAPSHOT_FILE_MISSING"
const FAILURE_SNAPSHOT_HASH_MISMATCH := "CERTIFICATION_QUALIFICATION_SNAPSHOT_HASH_MISMATCH"
const FAILURE_KNOWN_CERTIFICATIONS_INVALID := "KNOWN_CERTIFICATIONS_REGISTRY_INVALID"
const FAILURE_KNOWN_CERTIFICATIONS_HASH_MISMATCH := "KNOWN_CERTIFICATIONS_REGISTRY_HASH_MISMATCH"
const FAILURE_KNOWN_CERTIFICATION_UNKNOWN := "KNOWN_CERTIFICATION_UNKNOWN"

const PROFILE_SCHEMA_PATH := (
	"res://data/lab/schemas/" + "certification_qualification_profile_v1.schema.json"
)
const PROFILE_SCHEMA_SHA256 := "sha256:31c92c75d28381b05b490b8e138ad99ffc91547ce7718c514625f45e3e8d7a56"
const KNOWN_CERTIFICATIONS_PATH := "res://data/lab/legacy/br1_report_v1/known_certifications_v1.json"
const KNOWN_CERTIFICATIONS_SHA256 := "sha256:47c86975cbea3915579df352c061195769756afe88a610c50e2c49dd05066066"

const _PROFILE_REGISTRY := {
	"BR1_L0_V1_R001_I45":
	{
		"path": "res://data/lab/certification_profiles/" + "br1_l0_v1_r001_i45.json",
		"sha256": "sha256:0214df393c6317d1cb096c33f1bdc38d" + "fd057c414fc10ce24290418990bb191d",
	},
	"BR1_L0_V1_R002_I51":
	{
		"path": "res://data/lab/certification_profiles/" + "br1_l0_v1_r002_i51.json",
		"sha256": "sha256:2d1b985f453f8a8f6c469f84547da9a" + "c126c5445a5515bc4a72e06af2d62c7ac",
	},
}

const _SNAPSHOT_HASHES := {
	"res://data/lab/legacy/br1_report_v1/r001_i45/BR1_required_lab_tests_v1.snapshot.json":
	"sha256:4e090096c4009e1406214307a80e4648" + "0e80efbb4228f30df8efdc9de4ff13f6",
	"res://data/lab/legacy/br1_report_v1/r001_i45/br1_certification_report_v1.snapshot.schema.json":
	"sha256:f7596fcaf798c1c4627d5cef1af4bda4" + "136cbf08346acf00284e13f23e502567",
	"res://data/lab/legacy/br1_report_v1/r002_i51/BR1_required_lab_tests_v1.snapshot.json":
	"sha256:f287e53d6b47fad15205a8ed416b0616" + "e5eaae694453cd661c6eb08e1e2b79fa",
	"res://data/lab/legacy/br1_report_v1/r002_i51/br1_certification_report_v1.snapshot.schema.json":
	"sha256:f42f060962fd2870f36c9e615d9efea5" + "af1e2744f36f3c95e9ed4f46991b7be8",
	"res://data/lab/legacy/br1_report_v1/common/BR1_L0_certification_v1.snapshot.json":
	"sha256:c8146b00bfabfd2c4784cf2907ef6824" + "4d03388ccc184a9d16a99d49423419cd",
	(
		"res://data/lab/legacy/br1_report_v1/common/"
		+ "certification_report_attestation_v1.snapshot.schema.json"
	):
	"sha256:8cb6aceefa9b11bbd6756b91185c6f00" + "adea06633633929d5c588d2a1804d716",
}

const _DISPATCH_KEYS := [
	"report_schema",
	"inventory_sha256",
	"tests_required",
	"test_artifacts_required",
	"campaign_id",
	"campaign_sha256",
]

const _DISPATCH_PROFILES := {
	(
		"sporespore.lab.br1_certification_report.v1|"
		+ "sha256:4e090096c4009e1406214307a80e46480e80efbb4228f30df8efdc9de4ff13f6|"
		+ "45|90|BR1_L0_CERTIFICATION_V1|"
		+ "sha256:c8146b00bfabfd2c4784cf2907ef68244d03388ccc184a9d16a99d49423419cd"
	):
	"BR1_L0_V1_R001_I45",
	(
		"sporespore.lab.br1_certification_report.v1|"
		+ "sha256:f287e53d6b47fad15205a8ed416b0616e5eaae694453cd661c6eb08e1e2b79fa|"
		+ "51|102|BR1_L0_CERTIFICATION_V1|"
		+ "sha256:c8146b00bfabfd2c4784cf2907ef68244d03388ccc184a9d16a99d49423419cd"
	):
	"BR1_L0_V1_R002_I51",
}


static func profile_ids() -> Array[String]:
	var ids: Array[String] = []
	for id_value in _PROFILE_REGISTRY.keys():
		ids.append(String(id_value))
	ids.sort()
	return ids


static func dispatch(identity: Dictionary) -> Dictionary:
	var normalized := _normalize_dispatch_identity(identity)
	if not bool(normalized.get("ok", false)):
		return normalized
	var normalized_identity: Dictionary = normalized["identity"]
	var key := _dispatch_key(normalized_identity)
	if not _DISPATCH_PROFILES.has(key):
		return _failure(
			FAILURE_PROFILE_UNKNOWN,
			"No allowlisted qualification profile matches the exact report tuple.",
			{"dispatch_identity": normalized_identity.duplicate(true)}
		)
	var result := load_by_id(String(_DISPATCH_PROFILES[key]))
	if bool(result.get("ok", false)):
		result["dispatch_identity"] = normalized_identity.duplicate(true)
	return result


static func dispatch_report(report: Dictionary) -> Dictionary:
	var inventory_value: Variant = report.get("test_inventory")
	var campaign_value: Variant = report.get("campaign")
	if typeof(inventory_value) != TYPE_DICTIONARY or typeof(campaign_value) != TYPE_DICTIONARY:
		return _failure(
			FAILURE_DISPATCH_IDENTITY_INVALID,
			"Report dispatch requires test_inventory and campaign objects."
		)
	var inventory: Dictionary = inventory_value
	var campaign: Dictionary = campaign_value
	var artifacts_value: Variant = inventory.get("artifacts")
	if typeof(artifacts_value) != TYPE_ARRAY:
		return _failure(
			FAILURE_DISPATCH_IDENTITY_INVALID,
			"Report dispatch requires the concrete test-artifact array."
		)
	return dispatch(
		{
			"report_schema": report.get("schema"),
			"inventory_sha256": inventory.get("sha256"),
			"tests_required": inventory.get("required"),
			"test_artifacts_required": (artifacts_value as Array).size(),
			"campaign_id": campaign.get("campaign_id"),
			"campaign_sha256": campaign.get("sha256"),
		}
	)


static func load_by_id(profile_id: String) -> Dictionary:
	if not _PROFILE_REGISTRY.has(profile_id):
		return _failure(
			FAILURE_PROFILE_UNKNOWN,
			"Qualification profile ID is not present in the fixed allowlist.",
			{"profile_id": profile_id}
		)
	var entry: Dictionary = _PROFILE_REGISTRY[profile_id]
	var schema_check := _verify_resource_hash(
		PROFILE_SCHEMA_PATH,
		PROFILE_SCHEMA_SHA256,
		FAILURE_PROFILE_SCHEMA_HASH_MISMATCH,
		FAILURE_PROFILE_SCHEMA_HASH_MISMATCH,
		"Qualification profile schema"
	)
	if not bool(schema_check.get("ok", false)):
		return schema_check
	var profile_path := String(entry["path"])
	var profile_check := _verify_resource_hash(
		profile_path,
		String(entry["sha256"]),
		FAILURE_PROFILE_FILE_MISSING,
		FAILURE_PROFILE_HASH_MISMATCH,
		"Qualification profile"
	)
	if not bool(profile_check.get("ok", false)):
		return profile_check
	var loaded := _read_json_object(profile_path)
	if not bool(loaded.get("ok", false)):
		return _failure(
			FAILURE_PROFILE_INVALID,
			"Qualification profile is not a readable JSON object.",
			{
				"profile_id": profile_id,
				"profile_path": profile_path,
				"detail": loaded.get("message", ""),
			}
		)
	var profile: Dictionary = loaded["value"]
	var schema_result := SchemaValidatorScript.validate_file(PROFILE_SCHEMA_PATH, profile)
	if not bool(schema_result.get("ok", false)):
		return _failure(
			FAILURE_PROFILE_INVALID,
			"Qualification profile fails its strict owned schema.",
			{
				"profile_id": profile_id,
				"profile_path": profile_path,
				"schema_errors": schema_result.get("errors", []),
			}
		)
	var semantic_result := _validate_profile_semantics(profile_id, profile)
	if not bool(semantic_result.get("ok", false)):
		return semantic_result
	var snapshots_result := _verify_profile_snapshots(profile_id, profile)
	if not bool(snapshots_result.get("ok", false)):
		return snapshots_result
	return {
		"ok": true,
		"failure_code": "",
		"profile_id": profile_id,
		"profile_path": profile_path,
		"profile_sha256": String(entry["sha256"]),
		"legacy_schema_collision": true,
		"legacy_verification_only": true,
		"profile": profile.duplicate(true),
	}


static func load_known_certifications() -> Dictionary:
	var hash_result := _verify_resource_hash(
		KNOWN_CERTIFICATIONS_PATH,
		KNOWN_CERTIFICATIONS_SHA256,
		FAILURE_KNOWN_CERTIFICATIONS_HASH_MISMATCH,
		FAILURE_KNOWN_CERTIFICATIONS_HASH_MISMATCH,
		"Known-certifications registry"
	)
	if not bool(hash_result.get("ok", false)):
		return hash_result
	var loaded := _read_json_object(KNOWN_CERTIFICATIONS_PATH)
	if not bool(loaded.get("ok", false)):
		return _failure(
			FAILURE_KNOWN_CERTIFICATIONS_INVALID,
			"Known-certifications registry is not a readable JSON object."
		)
	var registry: Dictionary = loaded["value"]
	if not _has_exact_keys(
		registry,
		[
			"schema",
			"registry_version",
			"purpose",
			"legacy_schema_collision",
			"certifications",
		]
	):
		return _failure(
			FAILURE_KNOWN_CERTIFICATIONS_INVALID,
			"Known-certifications registry root is not closed and exact."
		)
	var certifications_value: Variant = registry.get("certifications")
	if (
		String(registry.get("schema", "")) != "sporespore.lab.known_br1_certifications.v1"
		or int(registry.get("registry_version", -1)) != 1
		or String(registry.get("purpose", "")) != "discovery_only_not_attestation"
		or registry.get("legacy_schema_collision") != true
		or typeof(certifications_value) != TYPE_ARRAY
		or (certifications_value as Array).size() != 2
	):
		return _failure(
			FAILURE_KNOWN_CERTIFICATIONS_INVALID,
			"Known-certifications registry identity or cardinality is invalid."
		)
	var seen_ids: Dictionary = {}
	for certificate_value in certifications_value:
		if typeof(certificate_value) != TYPE_DICTIONARY:
			return _failure(
				FAILURE_KNOWN_CERTIFICATIONS_INVALID, "Known-certification entries must be objects."
			)
		var certificate: Dictionary = certificate_value
		var certificate_result := _validate_known_certificate(certificate)
		if not bool(certificate_result.get("ok", false)):
			return certificate_result
		var certification_id := String(certificate["certification_id"])
		if seen_ids.has(certification_id):
			return _failure(
				FAILURE_KNOWN_CERTIFICATIONS_INVALID,
				"Known-certification IDs must be unique.",
				{"certification_id": certification_id}
			)
		seen_ids[certification_id] = true
	return {
		"ok": true,
		"failure_code": "",
		"registry_path": KNOWN_CERTIFICATIONS_PATH,
		"registry_sha256": KNOWN_CERTIFICATIONS_SHA256,
		"certifications": (certifications_value as Array).duplicate(true),
	}


static func known_certification(certification_id: String) -> Dictionary:
	var loaded := load_known_certifications()
	if not bool(loaded.get("ok", false)):
		return loaded
	for certificate_value in loaded["certifications"]:
		var certificate: Dictionary = certificate_value
		if String(certificate["certification_id"]) == certification_id:
			return {
				"ok": true,
				"failure_code": "",
				"certification": certificate.duplicate(true),
			}
	return _failure(
		FAILURE_KNOWN_CERTIFICATION_UNKNOWN,
		"Certification ID is not in the immutable discovery registry.",
		{"certification_id": certification_id}
	)


static func _normalize_dispatch_identity(identity: Dictionary) -> Dictionary:
	if not _has_exact_keys(identity, _DISPATCH_KEYS):
		return _failure(
			FAILURE_DISPATCH_IDENTITY_INVALID,
			"Dispatch identity must contain exactly the six qualification fields."
		)
	for field in [
		"report_schema",
		"inventory_sha256",
		"campaign_id",
		"campaign_sha256",
	]:
		if typeof(identity[field]) not in [TYPE_STRING, TYPE_STRING_NAME]:
			return _failure(
				FAILURE_DISPATCH_IDENTITY_INVALID,
				"Dispatch string field has the wrong type.",
				{"field": field}
			)
	var tests_result := _exact_nonnegative_integer(identity["tests_required"])
	var artifacts_result := _exact_nonnegative_integer(identity["test_artifacts_required"])
	if not bool(tests_result.get("ok", false)):
		return _failure(
			FAILURE_DISPATCH_IDENTITY_INVALID,
			"tests_required must be an exact non-negative integer."
		)
	if not bool(artifacts_result.get("ok", false)):
		return _failure(
			FAILURE_DISPATCH_IDENTITY_INVALID,
			"test_artifacts_required must be an exact non-negative integer."
		)
	return {
		"ok": true,
		"identity":
		{
			"report_schema": String(identity["report_schema"]),
			"inventory_sha256": String(identity["inventory_sha256"]),
			"tests_required": int(tests_result["value"]),
			"test_artifacts_required": int(artifacts_result["value"]),
			"campaign_id": String(identity["campaign_id"]),
			"campaign_sha256": String(identity["campaign_sha256"]),
		},
	}


static func _exact_nonnegative_integer(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_INT and int(value) >= 0:
		return {"ok": true, "value": int(value)}
	if (
		typeof(value) == TYPE_FLOAT
		and is_finite(float(value))
		and floor(float(value)) == float(value)
		and float(value) >= 0.0
	):
		return {"ok": true, "value": int(value)}
	return {"ok": false}


static func _dispatch_key(identity: Dictionary) -> String:
	return (
		"%s|%s|%d|%d|%s|%s"
		% [
			String(identity["report_schema"]),
			String(identity["inventory_sha256"]),
			int(identity["tests_required"]),
			int(identity["test_artifacts_required"]),
			String(identity["campaign_id"]),
			String(identity["campaign_sha256"]),
		]
	)


static func _identity_from_profile(profile: Dictionary) -> Dictionary:
	var report: Dictionary = profile["report_contract"]
	var inventory: Dictionary = profile["inventory_contract"]
	var campaign: Dictionary = profile["campaign_contract"]
	return {
		"report_schema": String(report["schema_id"]),
		"inventory_sha256": String(inventory["snapshot"]["sha256"]),
		"tests_required": int(inventory["test_count"]),
		"test_artifacts_required": int(inventory["artifact_count"]),
		"campaign_id": String(campaign["campaign_id"]),
		"campaign_sha256": String(campaign["snapshot"]["sha256"]),
	}


static func _validate_profile_semantics(profile_id: String, profile: Dictionary) -> Dictionary:
	if String(profile.get("profile_id", "")) != profile_id:
		return _failure(
			FAILURE_PROFILE_INVALID,
			"Profile payload ID does not match its allowlist key.",
			{"profile_id": profile_id}
		)
	var inventory: Dictionary = profile["inventory_contract"]
	var cardinality: Dictionary = profile["cardinality"]
	var tests_required := int(inventory["test_count"])
	var artifacts_required := int(inventory["artifact_count"])
	if (
		tests_required != int(cardinality["tests_required"])
		or artifacts_required != int(cardinality["test_artifacts_required"])
		or artifacts_required != tests_required * 2
	):
		return _failure(
			FAILURE_PROFILE_INVALID,
			"Profile test and artifact cardinalities disagree.",
			{"profile_id": profile_id}
		)
	var identity := _identity_from_profile(profile)
	var key := _dispatch_key(identity)
	if not _DISPATCH_PROFILES.has(key) or String(_DISPATCH_PROFILES[key]) != profile_id:
		return _failure(
			FAILURE_PROFILE_INVALID,
			"Profile payload has no exact matching dispatch tuple.",
			{
				"profile_id": profile_id,
				"dispatch_identity": identity,
			}
		)
	return {"ok": true}


static func _verify_profile_snapshots(profile_id: String, profile: Dictionary) -> Dictionary:
	var snapshots: Array = [
		profile["report_contract"]["snapshot"],
		profile["inventory_contract"]["snapshot"],
		profile["campaign_contract"]["snapshot"],
		profile["receipt_contract"]["snapshot"],
	]
	for snapshot_value in snapshots:
		var snapshot: Dictionary = snapshot_value
		var path := String(snapshot["resource_path"])
		var declared_hash := String(snapshot["sha256"])
		if not _SNAPSHOT_HASHES.has(path):
			return _failure(
				FAILURE_SNAPSHOT_NOT_ALLOWLISTED,
				"Profile references a snapshot outside the fixed allowlist.",
				{
					"profile_id": profile_id,
					"snapshot_path": path,
				}
			)
		var expected_hash := String(_SNAPSHOT_HASHES[path])
		if declared_hash != expected_hash:
			return _failure(
				FAILURE_PROFILE_INVALID,
				"Profile-declared snapshot hash differs from the allowlist.",
				{
					"profile_id": profile_id,
					"snapshot_path": path,
					"declared_sha256": declared_hash,
					"expected_sha256": expected_hash,
				}
			)
		var hash_result := _verify_resource_hash(
			path,
			expected_hash,
			FAILURE_SNAPSHOT_FILE_MISSING,
			FAILURE_SNAPSHOT_HASH_MISMATCH,
			"Historical qualification snapshot"
		)
		if not bool(hash_result.get("ok", false)):
			hash_result["profile_id"] = profile_id
			return hash_result
	return {"ok": true}


static func _validate_known_certificate(certificate: Dictionary) -> Dictionary:
	if not _has_exact_keys(
		certificate,
		[
			"certification_id",
			"profile_id",
			"profile_sha256",
			"repository_commit_sha",
			"generated_utc",
			"report",
			"receipt",
			"campaign",
			"inventory",
			"test_report",
			"operator_self_tests",
		]
	):
		return _failure(
			FAILURE_KNOWN_CERTIFICATIONS_INVALID,
			"Known-certification entry is not closed and exact."
		)
	var profile_id := String(certificate.get("profile_id", ""))
	if not _PROFILE_REGISTRY.has(profile_id):
		return _failure(
			FAILURE_KNOWN_CERTIFICATIONS_INVALID,
			"Known certification references an unknown profile.",
			{"profile_id": profile_id}
		)
	var profile_entry: Dictionary = _PROFILE_REGISTRY[profile_id]
	if String(certificate.get("profile_sha256", "")) != String(profile_entry["sha256"]):
		return _failure(
			FAILURE_KNOWN_CERTIFICATIONS_INVALID,
			"Known certification pins the wrong profile bytes.",
			{"profile_id": profile_id}
		)
	for object_field in [
		"report",
		"receipt",
		"campaign",
		"inventory",
		"test_report",
		"operator_self_tests",
	]:
		if typeof(certificate.get(object_field)) != TYPE_DICTIONARY:
			return _failure(
				FAILURE_KNOWN_CERTIFICATIONS_INVALID,
				"Known-certification nested field must be an object.",
				{"field": object_field}
			)
	var report: Dictionary = certificate["report"]
	var campaign: Dictionary = certificate["campaign"]
	var inventory: Dictionary = certificate["inventory"]
	var dispatch_result := dispatch(
		{
			"report_schema": report.get("schema"),
			"inventory_sha256": inventory.get("sha256"),
			"tests_required": inventory.get("tests_required"),
			"test_artifacts_required": inventory.get("test_artifacts_required"),
			"campaign_id": campaign.get("campaign_id"),
			"campaign_sha256": campaign.get("sha256"),
		}
	)
	if (
		not bool(dispatch_result.get("ok", false))
		or String(dispatch_result.get("profile_id", "")) != profile_id
	):
		return _failure(
			FAILURE_KNOWN_CERTIFICATIONS_INVALID,
			"Known certification does not dispatch to its pinned profile.",
			{
				"certification_id": String(certificate.get("certification_id", "")),
				"profile_id": profile_id,
			}
		)
	if (
		not _is_git_sha1(String(certificate.get("repository_commit_sha", "")))
		or not _is_sha256(String(report.get("sha256", "")))
		or not _is_sha256(String(certificate["receipt"].get("sha256", "")))
		or not _is_sha256(String(certificate["test_report"].get("sha256", "")))
	):
		return _failure(
			FAILURE_KNOWN_CERTIFICATIONS_INVALID,
			"Known certification contains a malformed identity digest."
		)
	return {"ok": true}


static func _verify_resource_hash(
	resource_path: String,
	expected_sha256: String,
	missing_code: String,
	mismatch_code: String,
	label: String
) -> Dictionary:
	if not FileAccess.file_exists(resource_path):
		return _failure(
			missing_code, "%s file is missing." % label, {"resource_path": resource_path}
		)
	var actual_sha256 := _resource_sha256(resource_path)
	if actual_sha256 != expected_sha256:
		return _failure(
			mismatch_code,
			"%s bytes differ from the immutable allowlist." % label,
			{
				"resource_path": resource_path,
				"expected_sha256": expected_sha256,
				"actual_sha256": actual_sha256,
			}
		)
	return {"ok": true}


static func _resource_sha256(resource_path: String) -> String:
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	var digest := FileAccess.get_sha256(absolute_path)
	if digest.is_empty():
		return ""
	return "sha256:%s" % digest.to_lower()


static func _read_json_object(resource_path: String) -> Dictionary:
	var file := FileAccess.open(resource_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "file open failed"}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	if parse_error != OK:
		return {
			"ok": false,
			"message":
			(
				"JSON parse failed at line %d: %s"
				% [
					parser.get_error_line(),
					parser.get_error_message(),
				]
			),
		}
	if typeof(parser.data) != TYPE_DICTIONARY:
		return {"ok": false, "message": "JSON root is not an object"}
	return {"ok": true, "value": parser.data}


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_value in expected:
		if not value.has(key_value):
			return false
	return true


static func _is_sha256(value: String) -> bool:
	return value.length() == 71 and value.begins_with("sha256:") and _is_lower_hex(value.substr(7))


static func _is_git_sha1(value: String) -> bool:
	return value.length() == 40 and _is_lower_hex(value)


static func _is_lower_hex(value: String) -> bool:
	for index in value.length():
		var code := value.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true


static func _failure(code: String, message: String, details: Dictionary = {}) -> Dictionary:
	var result := {
		"ok": false,
		"failure_code": code,
		"message": message,
	}
	for key_value in details:
		result[key_value] = details[key_value]
	return result
