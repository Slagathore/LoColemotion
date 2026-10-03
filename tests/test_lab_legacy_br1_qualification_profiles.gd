extends SceneTree

const RegistryScript := preload("res://scripts/lab/certification_qualification_profile_registry.gd")
const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")

const PROFILE_PATHS := {
	"BR1_L0_V1_R001_I45": "res://data/lab/certification_profiles/br1_l0_v1_r001_i45.json",
	"BR1_L0_V1_R002_I51": "res://data/lab/certification_profiles/br1_l0_v1_r002_i51.json",
}
const PROFILE_HASHES := {
	"BR1_L0_V1_R001_I45":
	"sha256:0214df393c6317d1cb096c33f1bdc38d" + "fd057c414fc10ce24290418990bb191d",
	"BR1_L0_V1_R002_I51":
	"sha256:2d1b985f453f8a8f6c469f84547da9a" + "c126c5445a5515bc4a72e06af2d62c7ac",
}
const KNOWN_CERTIFICATION_IDS := [
	"br1_20260721T002052Z_40077d42",
	"br1_20260721T031825Z_18c8e4cb",
]

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Legacy BR1 qualification profile tests ===")
	_test_strict_profile_schema()
	_test_allowlisted_profile_loading()
	_test_loaded_profiles_are_caller_isolated()
	_test_known_certification_registry()
	_finish()


func _test_strict_profile_schema() -> void:
	print("- validates closed verification-only profile contracts")
	for profile_id_value in PROFILE_PATHS:
		var profile_id := String(profile_id_value)
		var profile := _read_object(String(PROFILE_PATHS[profile_id]))
		var result := SchemaValidatorScript.validate_file(
			RegistryScript.PROFILE_SCHEMA_PATH, profile
		)
		_check(bool(result.get("ok", false)), "%s passes the owned schema" % profile_id)
		var unknown := profile.duplicate(true)
		unknown["authoring_override"] = true
		var unknown_result := SchemaValidatorScript.validate_file(
			RegistryScript.PROFILE_SCHEMA_PATH, unknown
		)
		_check(
			not bool(unknown_result.get("ok", true)), "%s rejects unknown root fields" % profile_id
		)
		var authoring := profile.duplicate(true)
		authoring["attestation_creation_allowed"] = true
		authoring["lifecycle"] = "authoring"
		var authoring_result := SchemaValidatorScript.validate_file(
			RegistryScript.PROFILE_SCHEMA_PATH, authoring
		)
		_check(
			not bool(authoring_result.get("ok", true)),
			"%s cannot be relabeled as an authoring profile" % profile_id
		)


func _test_allowlisted_profile_loading() -> void:
	print("- pins profile, schema, and snapshot identities")
	_check(
		(
			RegistryScript.profile_ids()
			== [RegistryScript.PROFILE_R001_I45, RegistryScript.PROFILE_R002_I51]
		),
		"registry exposes exactly the two historical profiles"
	)
	for profile_id_value in PROFILE_PATHS:
		var profile_id := String(profile_id_value)
		var result := RegistryScript.load_by_id(profile_id)
		_check(bool(result.get("ok", false)), "%s loads from the allowlist" % profile_id)
		if not bool(result.get("ok", false)):
			printerr("    loader failure: ", result)
			continue
		var profile: Dictionary = result["profile"]
		_check(
			String(result["profile_sha256"]) == String(PROFILE_HASHES[profile_id]),
			"%s returns its exact profile SHA-256" % profile_id
		)
		_check(
			(
				profile["lifecycle"] == "verify_only"
				and profile["attestation_creation_allowed"] == false
				and result["legacy_schema_collision"] == true
				and result["legacy_verification_only"] == true
			),
			"%s remains explicitly legacy and verification-only" % profile_id
		)
		var inventory: Dictionary = profile["inventory_contract"]
		var cardinality: Dictionary = profile["cardinality"]
		_check(
			(
				int(inventory["test_count"]) == int(cardinality["tests_required"])
				and int(inventory["artifact_count"]) == int(cardinality["test_artifacts_required"])
				and int(inventory["artifact_count"]) == int(inventory["test_count"]) * 2
			),
			"%s closes cross-field test cardinality" % profile_id
		)
	var unknown := RegistryScript.load_by_id("BR1_L0_V1_R999_I999")
	_check(
		(
			not bool(unknown.get("ok", true))
			and unknown.get("failure_code") == RegistryScript.FAILURE_PROFILE_UNKNOWN
		),
		"unallowlisted profile IDs fail closed"
	)


func _test_loaded_profiles_are_caller_isolated() -> void:
	print("- returns deep copies instead of mutable registry state")
	var first := RegistryScript.load_by_id(RegistryScript.PROFILE_R001_I45)
	_check(bool(first.get("ok", false)), "R001 isolation fixture loads")
	if not bool(first.get("ok", false)):
		return
	first["profile"]["cardinality"]["tests_required"] = 999
	var second := RegistryScript.load_by_id(RegistryScript.PROFILE_R001_I45)
	_check(
		(
			bool(second.get("ok", false))
			and int(second["profile"]["cardinality"]["tests_required"]) == 45
		),
		"caller mutation cannot persist into the next profile load"
	)


func _test_known_certification_registry() -> void:
	print("- indexes the two sealed reports without replacing attestation")
	var registry := RegistryScript.load_known_certifications()
	_check(bool(registry.get("ok", false)), "known-certifications registry passes integrity")
	if not bool(registry.get("ok", false)):
		printerr("    known registry failure: ", registry)
		return
	_check(
		String(registry["registry_sha256"]) == RegistryScript.KNOWN_CERTIFICATIONS_SHA256,
		"known-certifications registry returns its pinned byte identity"
	)
	var seen: Array[String] = []
	for certificate_value in registry["certifications"]:
		var certificate: Dictionary = certificate_value
		seen.append(String(certificate["certification_id"]))
		var lookup := RegistryScript.known_certification(String(certificate["certification_id"]))
		_check(
			(
				bool(lookup.get("ok", false))
				and lookup["certification"]["profile_id"] == certificate["profile_id"]
			),
			"%s resolves to its immutable profile" % certificate["certification_id"]
		)
	_check(seen == KNOWN_CERTIFICATION_IDS, "registry contains exactly both sealed sessions")
	var unknown := RegistryScript.known_certification("br1_unknown")
	_check(
		(
			not bool(unknown.get("ok", true))
			and unknown.get("failure_code") == RegistryScript.FAILURE_KNOWN_CERTIFICATION_UNKNOWN
		),
		"unknown sealed-session IDs fail closed"
	)


static func _read_object(path: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	if typeof(parser.data) != TYPE_DICTIONARY:
		return {}
	return parser.data


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
