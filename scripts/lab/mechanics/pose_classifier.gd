class_name LabPoseClassifier
extends RefCounted

## Profile-specific BR12 pose classifier.
##
## Classification authority comes only from finite labeled anatomical axes,
## morphology-scaled height, and explicit semantic contact evidence.
## Ambiguous or missing evidence returns UNKNOWN rather than a guessed pose.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const CONFIGURATION_SCHEMA := "pose_classifier_configuration_v1"
const RESULT_SCHEMA := "pose_classification_result_v1"
const CONFIGURATION_FIELDS: Array[String] = [
	"schema_version",
	"upright_up_dot_min",
	"face_vertical_dot_min",
	"side_vertical_dot_min",
	"upright_height_ratio_min",
	"minimum_class_margin",
	"required_contact_roles",
	"automatic_creature_guidance_enabled",
]
const OBSERVATION_FIELDS: Array[String] = [
	"schema_version",
	"anatomical_right_world",
	"anatomical_up_world",
	"anatomical_forward_world",
	"support_height_m",
	"reference_stance_height_m",
	"contact_regions",
	"has_foot_support",
	"linear_speed_m_s",
	"angular_speed_rad_s",
	"stable_for_ticks",
	"sensor_valid",
]
const POSES: Array[String] = ["upright", "prone", "supine", "left_side", "right_side"]


static func build_configuration(configuration: Dictionary) -> Dictionary:
	if not _has_exact_fields(configuration, CONFIGURATION_FIELDS):
		return _failure("POSE_CLASSIFIER_CONFIGURATION_FIELDS_INVALID")
	if String(configuration.get("schema_version", "")) != CONFIGURATION_SCHEMA:
		return _failure("POSE_CLASSIFIER_SCHEMA_INVALID")
	for field in [
		"upright_up_dot_min",
		"face_vertical_dot_min",
		"side_vertical_dot_min",
		"upright_height_ratio_min",
		"minimum_class_margin",
	]:
		if not _finite_number(configuration.get(field)):
			return _failure("POSE_CLASSIFIER_THRESHOLD_INVALID", {"field": field})
	if (
		float(configuration["upright_up_dot_min"]) <= 0.5
		or float(configuration["upright_up_dot_min"]) >= 1.0
		or float(configuration["face_vertical_dot_min"]) <= 0.5
		or float(configuration["face_vertical_dot_min"]) >= 1.0
		or float(configuration["side_vertical_dot_min"]) <= 0.5
		or float(configuration["side_vertical_dot_min"]) >= 1.0
		or float(configuration["upright_height_ratio_min"]) <= 0.0
		or float(configuration["upright_height_ratio_min"]) >= 1.0
		or float(configuration["minimum_class_margin"]) <= 0.0
		or float(configuration["minimum_class_margin"]) >= 1.0
		or typeof(configuration.get("automatic_creature_guidance_enabled")) != TYPE_BOOL
		or bool(configuration["automatic_creature_guidance_enabled"])
	):
		return _failure("POSE_CLASSIFIER_THRESHOLD_INVALID")
	var role_result := _validate_required_roles(configuration.get("required_contact_roles"))
	if not bool(role_result.get("ok", false)):
		return role_result
	var sealed := configuration.duplicate(true)
	sealed["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	return {"ok": true, "configuration": sealed}


static func classify(configuration: Dictionary, observation: Dictionary) -> Dictionary:
	var compiled := build_configuration(configuration)
	if not bool(compiled.get("ok", false)):
		return compiled
	var config: Dictionary = compiled["configuration"]
	if not _has_exact_fields(observation, OBSERVATION_FIELDS):
		return _unknown(config, "POSE_FEATURE_FIELDS_INVALID", false)
	if (
		String(observation.get("schema_version", "")) != "labeled_box_pose_observation_v1"
		or typeof(observation.get("sensor_valid")) != TYPE_BOOL
		or not bool(observation["sensor_valid"])
	):
		return _unknown(config, "POSE_FEATURE_UNAVAILABLE", false)
	for axis_field in [
		"anatomical_right_world",
		"anatomical_up_world",
		"anatomical_forward_world",
	]:
		if typeof(observation.get(axis_field)) != TYPE_VECTOR3:
			return _unknown(config, "POSE_FEATURE_UNAVAILABLE", false)
		var axis: Vector3 = observation[axis_field]
		if not axis.is_finite() or absf(axis.length() - 1.0) > 1.0e-5:
			return _unknown(config, "POSE_FEATURE_UNAVAILABLE", false)
	for field in [
		"support_height_m",
		"reference_stance_height_m",
		"linear_speed_m_s",
		"angular_speed_rad_s",
	]:
		if not _finite_number(observation.get(field)):
			return _unknown(config, "POSE_FEATURE_UNAVAILABLE", false)
	if (
		float(observation["support_height_m"]) < 0.0
		or float(observation["reference_stance_height_m"]) <= 0.0
		or typeof(observation.get("has_foot_support")) != TYPE_BOOL
		or typeof(observation.get("stable_for_ticks")) != TYPE_INT
		or int(observation["stable_for_ticks"]) < 0
	):
		return _unknown(config, "POSE_FEATURE_UNAVAILABLE", false)
	var contacts_result := _contact_set(observation.get("contact_regions"))
	if not bool(contacts_result.get("ok", false)):
		return _unknown(config, "POSE_FEATURE_UNAVAILABLE", false)
	var contacts: Dictionary = contacts_result["contacts"]
	var required: Dictionary = config["required_contact_roles"]
	var up: Vector3 = observation["anatomical_up_world"]
	var forward: Vector3 = observation["anatomical_forward_world"]
	var right: Vector3 = observation["anatomical_right_world"]
	var normalized_height := (
		float(observation["support_height_m"]) / float(observation["reference_stance_height_m"])
	)
	var scores := {
		"upright":
		_score(
			up.dot(Vector3.UP),
			float(config["upright_up_dot_min"]),
			(
				bool(observation["has_foot_support"])
				and normalized_height >= float(config["upright_height_ratio_min"])
				and _has_any(contacts, required["upright"])
			)
		),
		"prone":
		_score(
			-forward.dot(Vector3.UP),
			float(config["face_vertical_dot_min"]),
			_has_any(contacts, required["prone"])
		),
		"supine":
		_score(
			forward.dot(Vector3.UP),
			float(config["face_vertical_dot_min"]),
			_has_any(contacts, required["supine"])
		),
		"left_side":
		_score(
			right.dot(Vector3.UP),
			float(config["side_vertical_dot_min"]),
			_has_any(contacts, required["left_side"])
		),
		"right_side":
		_score(
			-right.dot(Vector3.UP),
			float(config["side_vertical_dot_min"]),
			_has_any(contacts, required["right_side"])
		),
	}
	var ranked: Array = []
	for pose in POSES:
		ranked.append({"pose": pose, "score": float(scores[pose])})
	ranked.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			if not is_equal_approx(float(left["score"]), float(right["score"])):
				return float(left["score"]) > float(right["score"])
			return String(left["pose"]) < String(right["pose"])
	)
	var best: Dictionary = ranked[0]
	var second: Dictionary = ranked[1]
	var margin := float(best["score"]) - float(second["score"])
	var pose := String(best["pose"])
	var reason := ""
	if float(best["score"]) < 0.0:
		pose = "unknown"
		reason = "POSE_REQUIRED_EVIDENCE_MISSING"
	elif margin < float(config["minimum_class_margin"]):
		pose = "unknown"
		reason = "POSE_CLASS_AMBIGUOUS"
	var confidence := 0.0
	if pose != "unknown":
		confidence = clampf(minf(float(best["score"]), margin), 0.0, 1.0)
	return {
		"ok": true,
		"classification":
		{
			"schema_version": RESULT_SCHEMA,
			"configuration_sha256": config["configuration_sha256"],
			"pose": pose,
			"confidence": confidence,
			"sensor_valid": true,
			"stable_for_ticks": int(observation["stable_for_ticks"]),
			"reason": reason,
			"evidence":
			{
				"up_dot": up.dot(Vector3.UP),
				"forward_dot_up": forward.dot(Vector3.UP),
				"right_dot_up": right.dot(Vector3.UP),
				"normalized_height": normalized_height,
				"contact_regions": (contacts_result["roles"] as Array).duplicate(),
				"class_scores": scores,
				"best_second_margin": margin,
			},
			"automatic_creature_guidance_allowed": false,
			"recovery_actuation_authorized": false,
		},
	}


static func _unknown(config: Dictionary, reason: String, sensor_valid: bool) -> Dictionary:
	return {
		"ok": true,
		"classification":
		{
			"schema_version": RESULT_SCHEMA,
			"configuration_sha256": config["configuration_sha256"],
			"pose": "unknown",
			"confidence": 0.0,
			"sensor_valid": sensor_valid,
			"stable_for_ticks": 0,
			"reason": reason,
			"evidence": {},
			"automatic_creature_guidance_allowed": false,
			"recovery_actuation_authorized": false,
		},
	}


static func _score(direction: float, threshold: float, contact_evidence: bool) -> float:
	if not contact_evidence or direction < threshold:
		return -1.0
	return clampf((direction - threshold) / (1.0 - threshold), 0.0, 1.0)


static func _validate_required_roles(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("POSE_CLASSIFIER_REQUIRED_ROLES_INVALID")
	var roles: Dictionary = value
	if roles.size() != POSES.size():
		return _failure("POSE_CLASSIFIER_REQUIRED_ROLES_INVALID")
	for pose in POSES:
		if (
			not roles.has(pose)
			or typeof(roles[pose]) != TYPE_ARRAY
			or (roles[pose] as Array).is_empty()
		):
			return _failure("POSE_CLASSIFIER_REQUIRED_ROLES_INVALID")
		var unique: Dictionary = {}
		for role_value in roles[pose]:
			if typeof(role_value) != TYPE_STRING and typeof(role_value) != TYPE_STRING_NAME:
				return _failure("POSE_CLASSIFIER_REQUIRED_ROLES_INVALID")
			var role := String(role_value)
			if role.is_empty() or unique.has(role):
				return _failure("POSE_CLASSIFIER_REQUIRED_ROLES_INVALID")
			unique[role] = true
	return {"ok": true}


static func _contact_set(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return _failure("POSE_CONTACT_REGIONS_INVALID")
	var contacts: Dictionary = {}
	var roles: Array[String] = []
	for role_value in value:
		if typeof(role_value) != TYPE_STRING and typeof(role_value) != TYPE_STRING_NAME:
			return _failure("POSE_CONTACT_REGIONS_INVALID")
		var role := String(role_value)
		if role.is_empty() or contacts.has(role):
			return _failure("POSE_CONTACT_REGIONS_INVALID")
		contacts[role] = true
		roles.append(role)
	roles.sort()
	return {"ok": true, "contacts": contacts, "roles": roles}


static func _has_any(contacts: Dictionary, required: Array) -> bool:
	for role_value in required:
		if contacts.has(String(role_value)):
			return true
	return false


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
