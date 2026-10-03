class_name LabRecoveryProfile
extends RefCounted

## Immutable, anatomy-role-based BR12 recovery profile.
##
## A compiled profile is planning data only. It has no controller, force,
## contact-creation, repair, or guidance authority.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const SCHEMA := "recovery_profile_configuration_v1"
const PROFILE_FIELDS: Array[String] = [
	"schema_version",
	"profile_id",
	"accepted_start_poses",
	"required_joint_roles",
	"candidate_contact_roles",
	"forbidden_contact_roles",
	"phases",
	"maximum_duration_s",
	"minimum_torque_reserve_fraction",
	"automatic_creature_guidance_enabled",
	"actuation_authority",
]
const PHASE_FIELDS: Array[String] = [
	"phase_id",
	"required_joint_roles",
	"required_contact_roles",
	"required_reach_roles",
	"required_torque_nm",
	"required_power_w",
	"required_friction_ratio",
	"minimum_structural_margin_fraction",
	"maximum_duration_s",
	"success_dwell_ticks",
]


static func compile(profile: Dictionary) -> Dictionary:
	if not _has_exact_fields(profile, PROFILE_FIELDS):
		return _failure("RECOVERY_PROFILE_FIELDS_INVALID")
	if String(profile.get("schema_version", "")) != SCHEMA:
		return _failure("RECOVERY_PROFILE_SCHEMA_INVALID")
	if (
		not _stable_id(String(profile.get("profile_id", "")))
		or not _unique_ids(profile.get("accepted_start_poses"), false)
		or not _unique_ids(profile.get("required_joint_roles"), true)
		or not _unique_ids(profile.get("candidate_contact_roles"), true)
		or not _unique_ids(profile.get("forbidden_contact_roles"), true)
		or not _finite_number(profile.get("maximum_duration_s"))
		or float(profile["maximum_duration_s"]) <= 0.0
		or not _finite_number(profile.get("minimum_torque_reserve_fraction"))
		or float(profile["minimum_torque_reserve_fraction"]) < 0.0
		or float(profile["minimum_torque_reserve_fraction"]) >= 1.0
		or typeof(profile.get("automatic_creature_guidance_enabled")) != TYPE_BOOL
		or bool(profile["automatic_creature_guidance_enabled"])
		or typeof(profile.get("actuation_authority")) != TYPE_BOOL
		or bool(profile["actuation_authority"])
		or typeof(profile.get("phases")) != TYPE_ARRAY
		or (profile["phases"] as Array).is_empty()
	):
		return _failure("RECOVERY_PROFILE_SEMANTICS_INVALID")
	var candidate_set := _set_from_array(profile["candidate_contact_roles"])
	var forbidden_set := _set_from_array(profile["forbidden_contact_roles"])
	for role in candidate_set:
		if forbidden_set.has(role):
			return _failure("RECOVERY_PROFILE_CONTACT_ROLE_CONFLICT", {"role_id": role})
	var phase_ids: Dictionary = {}
	var phases: Array = []
	for phase_value in profile["phases"]:
		var phase_result := _compile_phase(phase_value, candidate_set)
		if not bool(phase_result.get("ok", false)):
			return phase_result
		var phase: Dictionary = phase_result["phase"]
		if phase_ids.has(String(phase["phase_id"])):
			return _failure("RECOVERY_PROFILE_PHASE_DUPLICATE")
		phase_ids[String(phase["phase_id"])] = true
		phases.append(phase)
	var sealed := profile.duplicate(true)
	sealed["phases"] = phases
	sealed["configuration_sha256"] = CanonicalJsonScript.sha256(profile)
	return {
		"ok": true,
		"profile": sealed,
		"actuation_authority": false,
		"automatic_creature_guidance_allowed": false,
	}


static func match_roles(
	profile: Dictionary,
	start_pose: String,
	available_joint_roles: Array,
	available_contact_roles: Array
) -> Dictionary:
	var compiled := compile(profile)
	if not bool(compiled.get("ok", false)):
		return compiled
	var sealed: Dictionary = compiled["profile"]
	if start_pose not in sealed["accepted_start_poses"]:
		return _match_failure(sealed, "RECOVERY_START_POSE_UNSUPPORTED", [], [])
	if (
		not _unique_ids(available_joint_roles, true)
		or not _unique_ids(available_contact_roles, true)
	):
		return _match_failure(sealed, "RECOVERY_AVAILABLE_ROLES_INVALID", [], [])
	var joints := _set_from_array(available_joint_roles)
	var contacts := _set_from_array(available_contact_roles)
	var missing_joints := _missing(sealed["required_joint_roles"], joints)
	var missing_contacts := _missing(sealed["candidate_contact_roles"], contacts)
	if not missing_joints.is_empty():
		return _match_failure(
			sealed, "RECOVERY_REQUIRED_JOINT_ROLE_MISSING", missing_joints, missing_contacts
		)
	if not missing_contacts.is_empty():
		return _match_failure(
			sealed, "RECOVERY_CANDIDATE_CONTACT_ROLE_MISSING", missing_joints, missing_contacts
		)
	return {
		"ok": true,
		"match":
		{
			"feasible": true,
			"reason": "",
			"profile_id": sealed["profile_id"],
			"profile_sha256": sealed["configuration_sha256"],
			"start_pose": start_pose,
			"missing_joint_roles": [],
			"missing_contact_roles": [],
			"actuation_authorized": false,
			"automatic_creature_guidance_allowed": false,
		},
	}


static func _compile_phase(value: Variant, candidate_set: Dictionary) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("RECOVERY_PHASE_INVALID")
	var phase: Dictionary = value
	if (
		not _has_exact_fields(phase, PHASE_FIELDS)
		or not _stable_id(String(phase.get("phase_id", "")))
		or not _unique_ids(phase.get("required_joint_roles"), true)
		or not _unique_ids(phase.get("required_contact_roles"), true)
		or not _unique_ids(phase.get("required_reach_roles"), true)
		or not _finite_map(phase.get("required_torque_nm"))
		or not _finite_map(phase.get("required_power_w"))
		or not _finite_number(phase.get("required_friction_ratio"))
		or float(phase["required_friction_ratio"]) < 0.0
		or not _finite_number(phase.get("minimum_structural_margin_fraction"))
		or float(phase["minimum_structural_margin_fraction"]) < 0.0
		or float(phase["minimum_structural_margin_fraction"]) >= 1.0
		or not _finite_number(phase.get("maximum_duration_s"))
		or float(phase["maximum_duration_s"]) <= 0.0
		or typeof(phase.get("success_dwell_ticks")) != TYPE_INT
		or int(phase["success_dwell_ticks"]) <= 0
	):
		return _failure("RECOVERY_PHASE_SEMANTICS_INVALID")
	for role_value in phase["required_contact_roles"]:
		if not candidate_set.has(String(role_value)):
			return _failure("RECOVERY_PHASE_CONTACT_ROLE_UNDECLARED")
	for role_value in phase["required_reach_roles"]:
		if not candidate_set.has(String(role_value)):
			return _failure("RECOVERY_PHASE_REACH_ROLE_UNDECLARED")
	var joint_set := _set_from_array(phase["required_joint_roles"])
	for role in (phase["required_torque_nm"] as Dictionary).keys():
		if not joint_set.has(String(role)) or float(phase["required_torque_nm"][role]) < 0.0:
			return _failure("RECOVERY_PHASE_TORQUE_ROLE_INVALID")
	for role in (phase["required_power_w"] as Dictionary).keys():
		if not joint_set.has(String(role)) or float(phase["required_power_w"][role]) < 0.0:
			return _failure("RECOVERY_PHASE_POWER_ROLE_INVALID")
	return {"ok": true, "phase": phase.duplicate(true)}


static func _match_failure(
	profile: Dictionary, reason: String, missing_joints: Array, missing_contacts: Array
) -> Dictionary:
	return {
		"ok": true,
		"match":
		{
			"feasible": false,
			"reason": reason,
			"profile_id": profile["profile_id"],
			"profile_sha256": profile["configuration_sha256"],
			"start_pose": "",
			"missing_joint_roles": missing_joints,
			"missing_contact_roles": missing_contacts,
			"actuation_authorized": false,
			"automatic_creature_guidance_allowed": false,
		},
	}


static func _finite_map(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	for key in value as Dictionary:
		if not _stable_id(String(key)) or not _finite_number((value as Dictionary)[key]):
			return false
	return true


static func _unique_ids(value: Variant, allow_empty: bool) -> bool:
	if typeof(value) != TYPE_ARRAY or (not allow_empty and (value as Array).is_empty()):
		return false
	var seen: Dictionary = {}
	for item_value in value:
		if typeof(item_value) != TYPE_STRING and typeof(item_value) != TYPE_STRING_NAME:
			return false
		var item := String(item_value)
		if not _stable_id(item) or seen.has(item):
			return false
		seen[item] = true
	return true


static func _set_from_array(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		result[String(value)] = true
	return result


static func _missing(required: Array, available: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for role_value in required:
		var role := String(role_value)
		if not available.has(role):
			result.append(role)
	result.sort()
	return result


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


static func _finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


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
