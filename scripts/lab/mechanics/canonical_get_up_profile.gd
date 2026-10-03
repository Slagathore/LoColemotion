class_name LabCanonicalGetUpProfile
extends RefCounted

## Strict BR13 laboratory profile for one constrained planar get-up.
##
## The front and rear rigid bodies each represent a mirrored limb pair. That
## symmetry collapse and the out-of-plane guide are material scaffolds, not
## morphology-general creature behavior.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA := "canonical_get_up_profile_v1"
const CLAIM_BOUNDARY := (
	"BR13 laboratory reference profile for one symmetry-collapsed quadruped "
	+ "recovering from semantic ventral-contact prone to a two-pair foot-supported "
	+ "stance in the sagittal X/Y plane. One front rigid-body limb pair and one rear "
	+ "rigid-body limb pair represent mirrored left/right anatomy. A material "
	+ "out-of-plane translation, roll, and yaw guide remains present and must be "
	+ "accounted. Only ordinary unilateral floor contacts are legal. A matched "
	+ "zero-command control is required. Any later positive conclusion is exactly "
	+ "constrained_planar_get_up for this profile and establishes no free-3D recovery, "
	+ "morphology transfer, gait, walking, repair, or automatic creature guidance."
)
const FIELDS: Array[String] = [
	"schema_version",
	"profile_id",
	"start_pose",
	"terminal_pose",
	"recovery_plane",
	"represented_limb_pairs",
	"legal_intermediate_contact_roles",
	"steady_stance_contact_roles",
	"forbidden_contact_roles",
	"guide_locked_dofs",
	"ordinary_unilateral_ground_contacts",
	"matched_zero_command_control_required",
	"seed_set",
	"positive_claim",
	"morphology_generalization_allowed",
	"free_3d_recovery_claim_allowed",
	"gait_claim_allowed",
	"walking_claim_allowed",
	"automatic_creature_guidance_allowed",
]


static func compile(configuration: Dictionary) -> Dictionary:
	if not _exact_fields(configuration, FIELDS):
		return _failure("CANONICAL_GET_UP_PROFILE_FIELDS_INVALID")
	if String(configuration.get("schema_version", "")) != SCHEMA:
		return _failure("CANONICAL_GET_UP_PROFILE_SCHEMA_INVALID")
	if (
		(
			String(configuration.get("profile_id", ""))
			!= "canonical_symmetry_collapsed_quadruped_prone_v1"
		)
		or String(configuration.get("start_pose", "")) != "prone"
		or String(configuration.get("terminal_pose", "")) != "stance"
		or String(configuration.get("recovery_plane", "")) != "sagittal_xy"
		or String(configuration.get("positive_claim", "")) != "constrained_planar_get_up"
	):
		return _failure("CANONICAL_GET_UP_PROFILE_IDENTITY_INVALID")
	var front_rear := _string_set(
		configuration.get("represented_limb_pairs"), ["front_pair", "rear_pair"]
	)
	if not bool(front_rear.get("ok", false)):
		return _failure("CANONICAL_GET_UP_LIMB_PAIR_ROLES_INVALID")
	var legal_contacts := _string_set(
		configuration.get("legal_intermediate_contact_roles"),
		["front_pair_distal", "rear_pair_distal", "ventral_body"]
	)
	if not bool(legal_contacts.get("ok", false)):
		return _failure("CANONICAL_GET_UP_LEGAL_CONTACTS_INVALID")
	var stance_contacts := _string_set(
		configuration.get("steady_stance_contact_roles"), ["front_pair_distal", "rear_pair_distal"]
	)
	if not bool(stance_contacts.get("ok", false)):
		return _failure("CANONICAL_GET_UP_STANCE_CONTACTS_INVALID")
	var forbidden_contacts := _string_set(
		configuration.get("forbidden_contact_roles"), ["dorsal_body", "head"]
	)
	if not bool(forbidden_contacts.get("ok", false)):
		return _failure("CANONICAL_GET_UP_FORBIDDEN_CONTACTS_INVALID")
	var guide_dofs := _string_set(
		configuration.get("guide_locked_dofs"), ["out_of_plane_translation_z", "roll_x", "yaw_y"]
	)
	if not bool(guide_dofs.get("ok", false)):
		return _failure("CANONICAL_GET_UP_GUIDE_BOUNDARY_INVALID")
	if not _positive_unique_ints(configuration.get("seed_set")):
		return _failure("CANONICAL_GET_UP_SEED_SET_INVALID")
	for field in [
		"ordinary_unilateral_ground_contacts",
		"matched_zero_command_control_required",
	]:
		if typeof(configuration.get(field)) != TYPE_BOOL or not bool(configuration[field]):
			return _failure("CANONICAL_GET_UP_REQUIRED_BOUNDARY_DISABLED:%s" % field)
	for field in [
		"morphology_generalization_allowed",
		"free_3d_recovery_claim_allowed",
		"gait_claim_allowed",
		"walking_claim_allowed",
		"automatic_creature_guidance_allowed",
	]:
		if typeof(configuration.get(field)) != TYPE_BOOL or bool(configuration[field]):
			return _failure("CANONICAL_GET_UP_FORBIDDEN_CLAIM_ENABLED:%s" % field)
	var sealed := configuration.duplicate(true)
	sealed["profile_sha256"] = CanonicalJsonScript.sha256(configuration)
	sealed["claim_boundary"] = CLAIM_BOUNDARY
	sealed["physical_execution_authorized"] = false
	return {"ok": true, "profile": FrozenValueScript.snapshot(sealed)}


static func _string_set(value: Variant, expected: Array[String]) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return {"ok": false}
	var actual: Array[String] = []
	var seen: Dictionary = {}
	for item in value:
		if typeof(item) != TYPE_STRING and typeof(item) != TYPE_STRING_NAME:
			return {"ok": false}
		var text := String(item)
		if text.is_empty() or seen.has(text):
			return {"ok": false}
		seen[text] = true
		actual.append(text)
	actual.sort()
	var target := expected.duplicate()
	target.sort()
	return {"ok": actual == target}


static func _positive_unique_ints(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY or (value as Array).is_empty():
		return false
	var seen: Dictionary = {}
	for item in value:
		if typeof(item) != TYPE_INT or int(item) <= 0 or seen.has(int(item)):
			return false
		seen[int(item)] = true
	return true


static func _exact_fields(value: Dictionary, expected: Array[String]) -> bool:
	if value.size() != expected.size():
		return false
	for field in expected:
		if not value.has(field):
			return false
	return true


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
