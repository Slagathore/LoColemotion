class_name LabRecoveryFeasibilityAnalyzer
extends RefCounted

## Conservative, pre-actuation BR12 phase-feasibility report.
##
## The analyzer rejects an obviously underpowered, unreachable, friction-
## incompatible, or structurally insufficient phase before any controller is
## allowed to exist. A positive result is fixture/profile feasibility only.

const RecoveryProfileScript := preload("res://scripts/lab/mechanics/recovery_profile.gd")

const CAPABILITY_FIELDS: Array[String] = [
	"available_joint_roles",
	"available_contact_roles",
	"reachable_contact_roles",
	"joint_capacities",
	"contact_friction_coefficients",
	"external_assistance_enabled",
	"automatic_creature_guidance_enabled",
]
const JOINT_CAPACITY_FIELDS: Array[String] = [
	"maximum_active_torque_nm",
	"maximum_power_w",
	"structural_torque_nm",
]


static func evaluate(
	profile: Dictionary, phase_index: int, start_pose: String, capabilities: Dictionary
) -> Dictionary:
	var compiled := RecoveryProfileScript.compile(profile)
	if not bool(compiled.get("ok", false)):
		return compiled
	var sealed: Dictionary = compiled["profile"]
	if phase_index < 0 or phase_index >= (sealed["phases"] as Array).size():
		return _failure("RECOVERY_PHASE_INDEX_INVALID")
	if not _has_exact_fields(capabilities, CAPABILITY_FIELDS):
		return _failure("RECOVERY_CAPABILITY_FIELDS_INVALID")
	if (
		typeof(capabilities.get("external_assistance_enabled")) != TYPE_BOOL
		or bool(capabilities["external_assistance_enabled"])
		or typeof(capabilities.get("automatic_creature_guidance_enabled")) != TYPE_BOOL
		or bool(capabilities["automatic_creature_guidance_enabled"])
	):
		return _failure("RECOVERY_CAPABILITY_ASSISTANCE_FORBIDDEN")
	var role_match := RecoveryProfileScript.match_roles(
		profile,
		start_pose,
		capabilities["available_joint_roles"],
		capabilities["available_contact_roles"]
	)
	if not bool(role_match.get("ok", false)):
		return role_match
	var match: Dictionary = role_match["match"]
	if not bool(match["feasible"]):
		return _report(sealed, phase_index, false, String(match["reason"]), {}, [], [])
	if not _unique_ids(capabilities.get("reachable_contact_roles")):
		return _failure("RECOVERY_REACH_ROLES_INVALID")
	if typeof(capabilities.get("joint_capacities")) != TYPE_DICTIONARY:
		return _failure("RECOVERY_JOINT_CAPACITIES_INVALID")
	if typeof(capabilities.get("contact_friction_coefficients")) != TYPE_DICTIONARY:
		return _failure("RECOVERY_FRICTION_CAPACITIES_INVALID")
	var phase: Dictionary = sealed["phases"][phase_index]
	var reachable := _set_from_array(capabilities["reachable_contact_roles"])
	var unreachable: Array[String] = []
	for role_value in phase["required_reach_roles"]:
		var role := String(role_value)
		if not reachable.has(role):
			unreachable.append(role)
	if not unreachable.is_empty():
		unreachable.sort()
		return _report(
			sealed, phase_index, false, "RECOVERY_CONTACT_UNREACHABLE", {}, [], unreachable
		)
	var capacities: Dictionary = capabilities["joint_capacities"]
	var torque_margins: Dictionary = {}
	var power_margins: Dictionary = {}
	var structural_margins: Dictionary = {}
	var missing_joints: Array[String] = []
	for role_value in phase["required_joint_roles"]:
		var role := String(role_value)
		if not capacities.has(role) or not _valid_joint_capacity(capacities[role]):
			missing_joints.append(role)
			continue
		var capacity: Dictionary = capacities[role]
		var required_torque := float((phase["required_torque_nm"] as Dictionary).get(role, 0.0))
		var required_power := float((phase["required_power_w"] as Dictionary).get(role, 0.0))
		var max_torque := float(capacity["maximum_active_torque_nm"])
		var max_power := float(capacity["maximum_power_w"])
		var structural := float(capacity["structural_torque_nm"])
		torque_margins[role] = (max_torque - required_torque) / maxf(max_torque, 1.0e-9)
		power_margins[role] = (max_power - required_power) / maxf(max_power, 1.0e-9)
		structural_margins[role] = (structural - required_torque) / maxf(structural, 1.0e-9)
	if not missing_joints.is_empty():
		missing_joints.sort()
		return _report(
			sealed, phase_index, false, "RECOVERY_JOINT_CAPACITY_MISSING", {}, missing_joints, []
		)
	var friction: Dictionary = capabilities["contact_friction_coefficients"]
	var friction_margins: Dictionary = {}
	for role_value in phase["required_contact_roles"]:
		var role := String(role_value)
		if not friction.has(role) or not _finite_nonnegative(friction[role]):
			return _report(
				sealed, phase_index, false, "RECOVERY_FRICTION_CAPACITY_MISSING", {}, [], []
			)
		var coefficient := float(friction[role])
		friction_margins[role] = (
			(coefficient - float(phase["required_friction_ratio"])) / maxf(coefficient, 1.0e-9)
		)
	var minima := {
		"torque_reserve_fraction": _minimum_value(torque_margins),
		"power_reserve_fraction": _minimum_value(power_margins),
		"structural_reserve_fraction": _minimum_value(structural_margins),
		"friction_reserve_fraction": _minimum_value(friction_margins),
	}
	var reason := ""
	if float(minima["torque_reserve_fraction"]) < float(sealed["minimum_torque_reserve_fraction"]):
		reason = "RECOVERY_STATIC_TORQUE_INSUFFICIENT"
	elif float(minima["power_reserve_fraction"]) < 0.0:
		reason = "RECOVERY_POWER_INSUFFICIENT"
	elif (
		float(minima["structural_reserve_fraction"])
		< float(phase["minimum_structural_margin_fraction"])
	):
		reason = "RECOVERY_STRUCTURAL_MARGIN_INSUFFICIENT"
	elif float(minima["friction_reserve_fraction"]) < 0.0:
		reason = "RECOVERY_FRICTION_INSUFFICIENT"
	var diagnostics := {
		"minimum_margins": minima,
		"torque_margins": torque_margins,
		"power_margins": power_margins,
		"structural_margins": structural_margins,
		"friction_margins": friction_margins,
	}
	return _report(sealed, phase_index, reason.is_empty(), reason, diagnostics, [], [])


static func _report(
	profile: Dictionary,
	phase_index: int,
	feasible: bool,
	reason: String,
	diagnostics: Dictionary,
	missing_joint_roles: Array,
	unreachable_contact_roles: Array
) -> Dictionary:
	var phase: Dictionary = profile["phases"][phase_index]
	return {
		"ok": true,
		"report":
		{
			"schema_version": "recovery_static_feasibility_report_v1",
			"profile_id": profile["profile_id"],
			"profile_sha256": profile["configuration_sha256"],
			"phase_id": phase["phase_id"],
			"phase_index": phase_index,
			"feasible": feasible,
			"reason": reason,
			"diagnostics": diagnostics,
			"missing_joint_roles": missing_joint_roles,
			"unreachable_contact_roles": unreachable_contact_roles,
			"evaluation_before_actuation": true,
			"actuation_operation_count": 0,
			"external_assistance_used": false,
			"automatic_creature_guidance_allowed": false,
			"getting_up_established": false,
		},
	}


static func _valid_joint_capacity(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var capacity: Dictionary = value
	if not _has_exact_fields(capacity, JOINT_CAPACITY_FIELDS):
		return false
	for field in JOINT_CAPACITY_FIELDS:
		if not _finite_nonnegative(capacity[field]):
			return false
	return (
		float(capacity["maximum_active_torque_nm"]) > 0.0
		and float(capacity["maximum_power_w"]) > 0.0
		and float(capacity["structural_torque_nm"]) > 0.0
	)


static func _minimum_value(values: Dictionary) -> float:
	if values.is_empty():
		return 1.0
	var minimum := INF
	for value in values.values():
		minimum = minf(minimum, float(value))
	return minimum


static func _unique_ids(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var seen: Dictionary = {}
	for item_value in value:
		if typeof(item_value) != TYPE_STRING and typeof(item_value) != TYPE_STRING_NAME:
			return false
		var item := String(item_value)
		if item.is_empty() or seen.has(item):
			return false
		seen[item] = true
	return true


static func _set_from_array(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		result[String(value)] = true
	return result


static func _finite_nonnegative(value: Variant) -> bool:
	return (
		(typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT)
		and is_finite(float(value))
		and float(value) >= 0.0
	)


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
