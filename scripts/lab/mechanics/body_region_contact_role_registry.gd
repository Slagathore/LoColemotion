class_name LabBodyRegionContactRoleRegistry
extends RefCounted

## Strict semantic body-region roles for BR12 pose and recovery observations.
##
## The registry describes what an observed contact may mean during a recovery
## analysis. It creates no contact, applies no force, and grants no stance or
## creature-guidance authority.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const SCHEMA := "body_region_contact_role_registry_configuration_v1"
const ROLE_FIELDS: Array[String] = [
	"role_id",
	"may_bear_recovery_load",
	"allowed_steady_stance",
	"pose_evidence_tags",
]
const CONFIGURATION_FIELDS: Array[String] = [
	"schema_version",
	"roles",
	"automatic_creature_guidance_enabled",
	"contact_creation_authority",
]


static func build_configuration(configuration: Dictionary) -> Dictionary:
	if not _has_exact_fields(configuration, CONFIGURATION_FIELDS):
		return _failure("BODY_REGION_ROLE_CONFIGURATION_FIELDS_INVALID")
	if String(configuration.get("schema_version", "")) != SCHEMA:
		return _failure("BODY_REGION_ROLE_SCHEMA_INVALID")
	if (
		typeof(configuration.get("roles")) != TYPE_ARRAY
		or (configuration["roles"] as Array).is_empty()
		or typeof(configuration.get("automatic_creature_guidance_enabled")) != TYPE_BOOL
		or bool(configuration["automatic_creature_guidance_enabled"])
		or typeof(configuration.get("contact_creation_authority")) != TYPE_BOOL
		or bool(configuration["contact_creation_authority"])
	):
		return _failure("BODY_REGION_ROLE_POLICY_INVALID")
	var seen: Dictionary = {}
	var roles: Array = []
	for role_value in configuration["roles"]:
		if typeof(role_value) != TYPE_DICTIONARY:
			return _failure("BODY_REGION_ROLE_INVALID")
		var role: Dictionary = role_value
		if not _has_exact_fields(role, ROLE_FIELDS):
			return _failure("BODY_REGION_ROLE_FIELDS_INVALID")
		var role_id := String(role.get("role_id", ""))
		if (
			not _stable_id(role_id)
			or seen.has(role_id)
			or typeof(role.get("may_bear_recovery_load")) != TYPE_BOOL
			or typeof(role.get("allowed_steady_stance")) != TYPE_BOOL
			or not _valid_tags(role.get("pose_evidence_tags"))
		):
			return _failure("BODY_REGION_ROLE_SEMANTICS_INVALID")
		seen[role_id] = true
		roles.append(role.duplicate(true))
	var sealed := configuration.duplicate(true)
	sealed["roles"] = roles
	sealed["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	return {"ok": true, "configuration": sealed}


static func observe_roles(configuration: Dictionary, observed_role_ids: Array) -> Dictionary:
	var compiled := build_configuration(configuration)
	if not bool(compiled.get("ok", false)):
		return compiled
	var known: Dictionary = {}
	for role_value in (compiled["configuration"] as Dictionary)["roles"]:
		var role: Dictionary = role_value
		known[String(role["role_id"])] = role
	var unique: Dictionary = {}
	var observations: Array = []
	for role_value in observed_role_ids:
		if typeof(role_value) != TYPE_STRING and typeof(role_value) != TYPE_STRING_NAME:
			return _failure("BODY_REGION_OBSERVATION_ROLE_INVALID")
		var role_id := String(role_value)
		if not known.has(role_id):
			return _failure("BODY_REGION_OBSERVATION_ROLE_UNKNOWN", {"role_id": role_id})
		if unique.has(role_id):
			return _failure("BODY_REGION_OBSERVATION_ROLE_DUPLICATE", {"role_id": role_id})
		unique[role_id] = true
		observations.append((known[role_id] as Dictionary).duplicate(true))
	observations.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return String(left["role_id"]) < String(right["role_id"])
	)
	return {
		"ok": true,
		"configuration_sha256": (compiled["configuration"] as Dictionary)["configuration_sha256"],
		"observed_roles": observations,
		"contact_creation_authority": false,
		"automatic_creature_guidance_allowed": false,
	}


static func _valid_tags(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var seen: Dictionary = {}
	for tag_value in value:
		if typeof(tag_value) != TYPE_STRING and typeof(tag_value) != TYPE_STRING_NAME:
			return false
		var tag := String(tag_value)
		if not _stable_id(tag) or seen.has(tag):
			return false
		seen[tag] = true
	return true


static func _stable_id(value: String) -> bool:
	if value.is_empty() or value.length() > 160:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		var valid := (
			(code >= 48 and code <= 57)
			or (code >= 65 and code <= 90)
			or (code >= 97 and code <= 122)
			or code == 46
			or code == 95
			or code == 45
		)
		if not valid or (index == 0 and code >= 48 and code <= 57):
			return false
	return true


static func _has_exact_fields(value: Dictionary, expected: Array[String]) -> bool:
	if value.size() != expected.size():
		return false
	for field in expected:
		if not value.has(field):
			return false
	return true


static func _failure(code: String, extra: Dictionary = {}) -> Dictionary:
	var result := {"ok": false, "failure_code": code}
	for key in extra:
		result[key] = extra[key]
	return result
