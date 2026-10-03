class_name LabProtectiveContactRoleRegistry
extends RefCounted

## Strict semantic registry for BR11 protective-fall contacts.
##
## A role is authoring metadata. It never creates contact and it never turns a
## raw solver manifold into a whole-system load measurement.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const CONFIGURATION_SCHEMA := "protective_contact_role_registry_configuration_v1"
const OBSERVATION_SCHEMA := "protective_contact_role_observation_v1"
const VALID_ROLES: Array[String] = [
	"protective_distal",
	"core_impact",
	"ordinary_support",
	"non_support",
]
const CONFIGURATION_FIELDS: Array[String] = [
	"schema_version",
	"registry_id",
	"roles",
	"automatic_creature_guidance_allowed",
]
const ROLE_FIELDS: Array[String] = [
	"body_id",
	"shape_id",
	"role",
]
const OBSERVATION_FIELDS: Array[String] = [
	"schema_version",
	"body_id",
	"shape_id",
	"counterparty_surface_tag",
	"contact_observed",
]


static func compile(configuration: Dictionary) -> Dictionary:
	var keys := _sorted_keys(configuration)
	var expected: Array = CONFIGURATION_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		return _failure("PROTECTIVE_ROLE_CONFIGURATION_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != CONFIGURATION_SCHEMA:
		return _failure("PROTECTIVE_ROLE_CONFIGURATION_SCHEMA_UNSUPPORTED")
	if not _stable_id(String(configuration.get("registry_id", ""))):
		return _failure("PROTECTIVE_ROLE_REGISTRY_ID_INVALID")
	if (
		not configuration.get("automatic_creature_guidance_allowed") is bool
		or bool(configuration["automatic_creature_guidance_allowed"])
	):
		return _failure("PROTECTIVE_ROLE_GUIDANCE_FORBIDDEN")
	if not configuration.get("roles") is Array:
		return _failure("PROTECTIVE_ROLE_LIST_INVALID")
	var roles: Array = configuration["roles"]
	if roles.is_empty():
		return _failure("PROTECTIVE_ROLE_LIST_EMPTY")
	var identities: Dictionary = {}
	var role_counts := {
		"protective_distal": 0,
		"core_impact": 0,
		"ordinary_support": 0,
		"non_support": 0,
	}
	for role_value in roles:
		if not role_value is Dictionary:
			return _failure("PROTECTIVE_ROLE_ENTRY_INVALID")
		var role: Dictionary = role_value
		var role_keys := _sorted_keys(role)
		var expected_role: Array = ROLE_FIELDS.duplicate()
		expected_role.sort()
		if role_keys != expected_role:
			return _failure("PROTECTIVE_ROLE_ENTRY_FIELD_SET_MISMATCH")
		var body_id := String(role.get("body_id", ""))
		var shape_id := String(role.get("shape_id", ""))
		var role_name := String(role.get("role", ""))
		if not _stable_id(body_id) or not _stable_id(shape_id):
			return _failure("PROTECTIVE_ROLE_SEMANTIC_ID_INVALID")
		if role_name not in VALID_ROLES:
			return _failure("PROTECTIVE_ROLE_VALUE_INVALID")
		var identity := "%s/%s" % [body_id, shape_id]
		if identities.has(identity):
			return _failure("PROTECTIVE_ROLE_IDENTITY_DUPLICATE")
		identities[identity] = role_name
		role_counts[role_name] = int(role_counts[role_name]) + 1
	if int(role_counts["protective_distal"]) < 1 or int(role_counts["core_impact"]) < 1:
		return _failure("PROTECTIVE_ROLE_REQUIRED_CLASS_MISSING")
	var payload := configuration.duplicate(true)
	payload["role_count"] = roles.size()
	payload["role_counts"] = role_counts
	payload["registry_sha256"] = CanonicalJsonScript.sha256(configuration)
	return {
		"ok": true,
		"registry": FrozenValueScript.snapshot(payload),
	}


static func classify(registry: Dictionary, observation: Dictionary) -> Dictionary:
	var source: Dictionary = {}
	for field in CONFIGURATION_FIELDS:
		if not registry.has(field):
			return _failure("PROTECTIVE_ROLE_REGISTRY_INCOMPLETE")
		source[field] = registry[field]
	var rebuilt := compile(source)
	if (
		not bool(rebuilt.get("ok", false))
		or (
			CanonicalJsonScript.stringify(rebuilt["registry"])
			!= CanonicalJsonScript.stringify(registry)
		)
	):
		return _failure("PROTECTIVE_ROLE_REGISTRY_DIGEST_MISMATCH")
	var keys := _sorted_keys(observation)
	var expected: Array = OBSERVATION_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		return _failure("PROTECTIVE_ROLE_OBSERVATION_FIELD_SET_MISMATCH")
	if String(observation.get("schema_version", "")) != OBSERVATION_SCHEMA:
		return _failure("PROTECTIVE_ROLE_OBSERVATION_SCHEMA_UNSUPPORTED")
	if not observation.get("contact_observed") is bool:
		return _failure("PROTECTIVE_ROLE_CONTACT_FLAG_INVALID")
	if not bool(observation["contact_observed"]):
		return {
			"ok": true,
			"observed": false,
			"role": null,
			"protective_contact": false,
			"core_contact": false,
		}
	if String(observation.get("counterparty_surface_tag", "")) != "lab_ground":
		return _failure("PROTECTIVE_ROLE_COUNTERPARTY_NOT_GROUND")
	var body_id := String(observation.get("body_id", ""))
	var shape_id := String(observation.get("shape_id", ""))
	for role_value in registry["roles"]:
		var role: Dictionary = role_value
		if String(role["body_id"]) == body_id and String(role["shape_id"]) == shape_id:
			var role_name := String(role["role"])
			return {
				"ok": true,
				"observed": true,
				"role": role_name,
				"protective_contact": role_name == "protective_distal",
				"core_contact": role_name == "core_impact",
			}
	return _failure("PROTECTIVE_ROLE_OBSERVATION_UNKNOWN")


static func _sorted_keys(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys


static func _stable_id(value: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^[A-Za-z][A-Za-z0-9._:-]{0,159}$")
	return expression.search(value) != null


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
