class_name LabQuadrupedRecoveryPoseObserver
extends RefCounted

## BR13 profile-specific prone/stance observer for the canonical quadruped.
##
## A quadruped can retain a near-horizontal torso in both prone and stance.
## Semantic contact, morphology-scaled height, stability, and sensor validity
## therefore remain authoritative; torso orientation alone is insufficient.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const CONFIGURATION_FIELDS: Array[String] = [
	"schema_version",
	"prone_height_ratio_max",
	"stance_height_ratio_min",
	"stable_linear_speed_m_s",
	"stable_angular_speed_rad_s",
	"automatic_creature_guidance_allowed",
]
const OBSERVATION_FIELDS: Array[String] = [
	"schema_version",
	"tick",
	"torso_height_m",
	"reference_stance_height_m",
	"linear_speed_m_s",
	"angular_speed_rad_s",
	"ventral_contact",
	"front_pair_bearing",
	"rear_pair_bearing",
	"forbidden_contact_roles",
	"sensor_valid",
]


static func build(configuration: Dictionary) -> Dictionary:
	if not _exact_fields(configuration, CONFIGURATION_FIELDS):
		return _failure("QUADRUPED_POSE_CONFIGURATION_FIELDS_INVALID")
	if (
		String(configuration.get("schema_version", ""))
		!= "quadruped_recovery_pose_configuration_v1"
	):
		return _failure("QUADRUPED_POSE_CONFIGURATION_SCHEMA_INVALID")
	for field in [
		"prone_height_ratio_max",
		"stance_height_ratio_min",
		"stable_linear_speed_m_s",
		"stable_angular_speed_rad_s",
	]:
		if not _finite_number(configuration.get(field)) or float(configuration[field]) < 0.0:
			return _failure("QUADRUPED_POSE_CONFIGURATION_NUMBER_INVALID:%s" % field)
	if (
		float(configuration["prone_height_ratio_max"]) <= 0.0
		or float(configuration["prone_height_ratio_max"]) >= 0.6
		or float(configuration["stance_height_ratio_min"]) <= 0.6
		or float(configuration["stance_height_ratio_min"]) > 1.0
		or (
			float(configuration["prone_height_ratio_max"])
			>= float(configuration["stance_height_ratio_min"])
		)
		or typeof(configuration.get("automatic_creature_guidance_allowed")) != TYPE_BOOL
		or bool(configuration["automatic_creature_guidance_allowed"])
	):
		return _failure("QUADRUPED_POSE_CONFIGURATION_BOUND_INVALID")
	var sealed := configuration.duplicate(true)
	sealed["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	return {"ok": true, "configuration": FrozenValueScript.snapshot(sealed)}


static func observe(configuration: Dictionary, observation: Dictionary) -> Dictionary:
	var compiled := build(configuration)
	if not bool(compiled.get("ok", false)):
		return compiled
	var config: Dictionary = compiled["configuration"]
	if not _exact_fields(observation, OBSERVATION_FIELDS):
		return _unknown(config, -1, "QUADRUPED_POSE_OBSERVATION_FIELDS_INVALID")
	if (
		String(observation.get("schema_version", "")) != "quadruped_recovery_pose_observation_v1"
		or typeof(observation.get("tick")) != TYPE_INT
		or int(observation["tick"]) < 0
		or typeof(observation.get("sensor_valid")) != TYPE_BOOL
		or not bool(observation["sensor_valid"])
	):
		return _unknown(config, int(observation.get("tick", -1)), "QUADRUPED_POSE_UNAVAILABLE")
	for field in [
		"torso_height_m",
		"reference_stance_height_m",
		"linear_speed_m_s",
		"angular_speed_rad_s",
	]:
		if not _finite_number(observation.get(field)) or float(observation[field]) < 0.0:
			return _unknown(config, int(observation["tick"]), "QUADRUPED_POSE_UNAVAILABLE")
	if float(observation["reference_stance_height_m"]) <= 0.0:
		return _unknown(config, int(observation["tick"]), "QUADRUPED_POSE_UNAVAILABLE")
	for field in ["ventral_contact", "front_pair_bearing", "rear_pair_bearing"]:
		if typeof(observation.get(field)) != TYPE_BOOL:
			return _unknown(config, int(observation["tick"]), "QUADRUPED_POSE_UNAVAILABLE")
	var forbidden := _roles(observation.get("forbidden_contact_roles"))
	if not bool(forbidden.get("ok", false)):
		return _unknown(config, int(observation["tick"]), "QUADRUPED_POSE_UNAVAILABLE")
	if not (forbidden["roles"] as Array).is_empty():
		return _unknown(config, int(observation["tick"]), "FORBIDDEN_CONTACT_OBSERVED")
	var ratio := (
		float(observation["torso_height_m"]) / float(observation["reference_stance_height_m"])
	)
	var stable := (
		float(observation["linear_speed_m_s"]) <= float(config["stable_linear_speed_m_s"])
		and (
			float(observation["angular_speed_rad_s"]) <= float(config["stable_angular_speed_rad_s"])
		)
	)
	var state := "TRANSITION"
	var reason := "BETWEEN_DECLARED_TERMINAL_STATES"
	if bool(observation["ventral_contact"]) and ratio <= float(config["prone_height_ratio_max"]):
		state = "PRONE"
		reason = "VENTRAL_LOW_SUPPORT"
	elif (
		not bool(observation["ventral_contact"])
		and bool(observation["front_pair_bearing"])
		and bool(observation["rear_pair_bearing"])
		and ratio >= float(config["stance_height_ratio_min"])
		and stable
	):
		state = "STANCE"
		reason = "TWO_PAIR_STABLE_SUPPORT"
	return {
		"ok": true,
		"observation":
		(
			FrozenValueScript
			. snapshot(
				{
					"schema_version": "quadruped_recovery_pose_result_v1",
					"configuration_sha256": config["configuration_sha256"],
					"tick": int(observation["tick"]),
					"state": state,
					"reason": reason,
					"height_ratio": ratio,
					"stable": stable,
					"ventral_contact": bool(observation["ventral_contact"]),
					"front_pair_bearing": bool(observation["front_pair_bearing"]),
					"rear_pair_bearing": bool(observation["rear_pair_bearing"]),
					"forbidden_contact_roles": forbidden["roles"],
					"force_authority": false,
					"automatic_creature_guidance_allowed": false,
				}
			)
		),
	}


static func _unknown(config: Dictionary, tick: int, reason: String) -> Dictionary:
	return {
		"ok": true,
		"observation":
		(
			FrozenValueScript
			. snapshot(
				{
					"schema_version": "quadruped_recovery_pose_result_v1",
					"configuration_sha256": config["configuration_sha256"],
					"tick": tick,
					"state": "UNKNOWN",
					"reason": reason,
					"height_ratio": null,
					"stable": false,
					"ventral_contact": false,
					"front_pair_bearing": false,
					"rear_pair_bearing": false,
					"forbidden_contact_roles": [],
					"force_authority": false,
					"automatic_creature_guidance_allowed": false,
				}
			)
		),
	}


static func _roles(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return {"ok": false}
	var roles: Array[String] = []
	var seen: Dictionary = {}
	for item in value:
		if typeof(item) != TYPE_STRING and typeof(item) != TYPE_STRING_NAME:
			return {"ok": false}
		var role := String(item)
		if role.is_empty() or seen.has(role):
			return {"ok": false}
		seen[role] = true
		roles.append(role)
	roles.sort()
	return {"ok": true, "roles": roles}


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _exact_fields(value: Dictionary, expected: Array[String]) -> bool:
	if value.size() != expected.size():
		return false
	for field in expected:
		if not value.has(field):
			return false
	return true


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
