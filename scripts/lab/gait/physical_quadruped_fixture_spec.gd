class_name LabPhysicalQuadrupedFixtureSpec
extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## Fail-closed physical fixture specification for the BR14A quadruped walker.
##
## The normalized record is deliberately JSON-safe. Its ordered limb array
## owns construction order, while gait timing and target policy remain outside
## this module so morphology changes cannot silently retune the controller.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const SCHEMA_VERSION := "sporespore_physical_quadruped_fixture_spec_v1"
const REFERENCE_LIMB_IDS := [
	"front_left",
	"front_right",
	"rear_left",
	"rear_right",
]
const TOP_LEVEL_KEYS := [
	"schema_version",
	"torso",
	"limbs",
	"collision_margin_m",
	"contact_material",
	"body_dynamics",
	"joint_limits",
	"motor_impulses",
]
const TORSO_KEYS := [
	"mass_kg",
	"size_m",
	"initial_center_m",
]
const LIMB_KEYS := [
	"limb_id",
	"hip_offset_from_torso_center_m",
	"upper_mass_kg",
	"distal_mass_kg",
	"upper_length_m",
	"lower_length_m",
	"upper_cross_section_m",
	"foot_radius_m",
]
const CONTACT_MATERIAL_KEYS := [
	"friction",
	"rough",
	"bounce",
	"absorbent",
]
const BODY_DYNAMICS_KEYS := [
	"can_sleep",
	"continuous_collision_detection",
	"linear_damp",
	"angular_damp",
	"collision_layer",
	"collision_mask",
	"maximum_reported_contacts",
]
const JOINT_LIMIT_KEYS := [
	"hip_lower_rad",
	"hip_upper_rad",
	"knee_lower_rad",
	"knee_upper_rad",
	"bias",
	"relaxation",
]
const MOTOR_IMPULSE_KEYS := [
	"hip_max_impulse_nms",
	"knee_base_max_impulse_nms",
]
const MINIMUM_UNIFORM_SCALE := 0.25
const MAXIMUM_UNIFORM_SCALE := 4.0


static func reference_spec() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"torso":
		{
			"mass_kg": 3.0,
			"size_m": [0.50, 0.12, 0.32],
			"initial_center_m": [0.0, 0.44, 0.0],
		},
		"limbs":
		[
			_reference_limb("front_left", 0.20, -0.18),
			_reference_limb("front_right", 0.20, 0.18),
			_reference_limb("rear_left", -0.20, -0.18),
			_reference_limb("rear_right", -0.20, 0.18),
		],
		"collision_margin_m": 0.002,
		"contact_material":
		{
			"friction": 1.8,
			"rough": true,
			"bounce": 0.0,
			"absorbent": true,
		},
		"body_dynamics":
		{
			"can_sleep": false,
			"continuous_collision_detection": true,
			"linear_damp": 0.08,
			"angular_damp": 0.15,
			"collision_layer": 2,
			"collision_mask": 1,
			"maximum_reported_contacts": 16,
		},
		"joint_limits":
		{
			"hip_lower_rad": -0.72,
			"hip_upper_rad": 0.72,
			"knee_lower_rad": -0.15,
			"knee_upper_rad": 1.10,
			"bias": 0.30,
			"relaxation": 1.0,
		},
		"motor_impulses":
		{
			"hip_max_impulse_nms": 0.055,
			"knee_base_max_impulse_nms": 0.045,
		},
	}


static func uniform_scaled_spec(scale_value: Variant) -> Dictionary:
	var scale_result := _positive_number(scale_value, "uniform_scale")
	if not bool(scale_result.get("ok", false)):
		return scale_result
	var uniform_scale := float(scale_result["value"])
	if uniform_scale < MINIMUM_UNIFORM_SCALE or uniform_scale > MAXIMUM_UNIFORM_SCALE:
		return _failure("UNIFORM_SCALE_OUT_OF_RANGE", "uniform_scale")
	var density_mass_scale := pow(uniform_scale, 3.0)
	var fixed_period_motor_impulse_scale := pow(uniform_scale, 5.0)
	var requested := reference_spec()
	var torso: Dictionary = requested["torso"]
	torso["mass_kg"] = float(torso["mass_kg"]) * density_mass_scale
	torso["size_m"] = _scaled_number_array(torso["size_m"], uniform_scale)
	torso["initial_center_m"] = _scaled_number_array(torso["initial_center_m"], uniform_scale)
	var limbs: Array = requested["limbs"]
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		limb["hip_offset_from_torso_center_m"] = _scaled_number_array(
			limb["hip_offset_from_torso_center_m"], uniform_scale
		)
		limb["upper_mass_kg"] = float(limb["upper_mass_kg"]) * density_mass_scale
		limb["distal_mass_kg"] = float(limb["distal_mass_kg"]) * density_mass_scale
		limb["upper_length_m"] = float(limb["upper_length_m"]) * uniform_scale
		limb["lower_length_m"] = float(limb["lower_length_m"]) * uniform_scale
		limb["upper_cross_section_m"] = _scaled_number_array(
			limb["upper_cross_section_m"], uniform_scale
		)
		limb["foot_radius_m"] = float(limb["foot_radius_m"]) * uniform_scale
	requested["collision_margin_m"] = (float(requested["collision_margin_m"]) * uniform_scale)
	var motor_impulses: Dictionary = requested["motor_impulses"]
	motor_impulses["hip_max_impulse_nms"] = (
		float(motor_impulses["hip_max_impulse_nms"]) * fixed_period_motor_impulse_scale
	)
	motor_impulses["knee_base_max_impulse_nms"] = (
		float(motor_impulses["knee_base_max_impulse_nms"]) * fixed_period_motor_impulse_scale
	)
	var compiled := compile(requested)
	if not bool(compiled.get("ok", false)):
		return compiled
	return {
		"ok": true,
		"uniform_scale": uniform_scale,
		"density_mass_scale": density_mass_scale,
		"fixed_period_motor_impulse_scale": fixed_period_motor_impulse_scale,
		"fixture_spec": (compiled["fixture_spec"] as Dictionary).duplicate(true),
		"fixture_spec_sha256": String(compiled["fixture_spec_sha256"]),
		"world_build_count": 0,
	}


static func dynamic_similarity_scaled_spec(scale_value: Variant) -> Dictionary:
	var scale_result := _positive_number(scale_value, "uniform_scale")
	if not bool(scale_result.get("ok", false)):
		return scale_result
	var uniform_scale := float(scale_result["value"])
	if uniform_scale < MINIMUM_UNIFORM_SCALE or uniform_scale > MAXIMUM_UNIFORM_SCALE:
		return _failure("UNIFORM_SCALE_OUT_OF_RANGE", "uniform_scale")
	var time_scale := sqrt(uniform_scale)
	var density_mass_scale := pow(uniform_scale, 3.0)
	var dynamic_similarity_motor_impulse_scale := pow(uniform_scale, 4.0)
	var inverse_time_scale := 1.0 / time_scale
	var requested := reference_spec()
	var torso: Dictionary = requested["torso"]
	torso["mass_kg"] = float(torso["mass_kg"]) * density_mass_scale
	torso["size_m"] = _scaled_number_array(torso["size_m"], uniform_scale)
	torso["initial_center_m"] = _scaled_number_array(torso["initial_center_m"], uniform_scale)
	var limbs: Array = requested["limbs"]
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		limb["hip_offset_from_torso_center_m"] = _scaled_number_array(
			limb["hip_offset_from_torso_center_m"], uniform_scale
		)
		limb["upper_mass_kg"] = float(limb["upper_mass_kg"]) * density_mass_scale
		limb["distal_mass_kg"] = float(limb["distal_mass_kg"]) * density_mass_scale
		limb["upper_length_m"] = float(limb["upper_length_m"]) * uniform_scale
		limb["lower_length_m"] = float(limb["lower_length_m"]) * uniform_scale
		limb["upper_cross_section_m"] = _scaled_number_array(
			limb["upper_cross_section_m"], uniform_scale
		)
		limb["foot_radius_m"] = float(limb["foot_radius_m"]) * uniform_scale
	requested["collision_margin_m"] = float(requested["collision_margin_m"]) * uniform_scale
	var body_dynamics: Dictionary = requested["body_dynamics"]
	body_dynamics["linear_damp"] = float(body_dynamics["linear_damp"]) * inverse_time_scale
	body_dynamics["angular_damp"] = float(body_dynamics["angular_damp"]) * inverse_time_scale
	var motor_impulses: Dictionary = requested["motor_impulses"]
	motor_impulses["hip_max_impulse_nms"] = (
		float(motor_impulses["hip_max_impulse_nms"]) * dynamic_similarity_motor_impulse_scale
	)
	motor_impulses["knee_base_max_impulse_nms"] = (
		float(motor_impulses["knee_base_max_impulse_nms"]) * dynamic_similarity_motor_impulse_scale
	)
	var compiled := compile(requested)
	if not bool(compiled.get("ok", false)):
		return compiled
	return {
		"ok": true,
		"uniform_scale": uniform_scale,
		"time_scale": time_scale,
		"density_mass_scale": density_mass_scale,
		"dynamic_similarity_motor_impulse_scale": dynamic_similarity_motor_impulse_scale,
		"body_damping_scale": inverse_time_scale,
		"fixture_spec": (compiled["fixture_spec"] as Dictionary).duplicate(true),
		"fixture_spec_sha256": String(compiled["fixture_spec_sha256"]),
		"world_build_count": 0,
	}


static func compile(requested: Dictionary = {}) -> Dictionary:
	var source := reference_spec() if requested.is_empty() else requested.duplicate(true)
	var keys_result := _validate_exact_keys(source, TOP_LEVEL_KEYS, "fixture_spec")
	if not bool(keys_result.get("ok", false)):
		return keys_result
	if typeof(source["schema_version"]) != TYPE_STRING:
		return _failure("INVALID_SCHEMA_VERSION", "schema_version")
	if String(source["schema_version"]) != SCHEMA_VERSION:
		return _failure("UNKNOWN_SCHEMA_VERSION", "schema_version")

	var torso_result := _normalize_torso(source["torso"])
	if not bool(torso_result.get("ok", false)):
		return torso_result
	var limbs_result := _normalize_limbs(
		source["limbs"],
		torso_result["torso"],
		source["collision_margin_m"],
	)
	if not bool(limbs_result.get("ok", false)):
		return limbs_result
	var collision_margin_result := _positive_number(
		source["collision_margin_m"], "collision_margin_m"
	)
	if not bool(collision_margin_result.get("ok", false)):
		return collision_margin_result
	var contact_result := _normalize_contact_material(source["contact_material"])
	if not bool(contact_result.get("ok", false)):
		return contact_result
	var dynamics_result := _normalize_body_dynamics(source["body_dynamics"])
	if not bool(dynamics_result.get("ok", false)):
		return dynamics_result
	var limits_result := _normalize_joint_limits(source["joint_limits"])
	if not bool(limits_result.get("ok", false)):
		return limits_result
	var impulses_result := _normalize_motor_impulses(source["motor_impulses"])
	if not bool(impulses_result.get("ok", false)):
		return impulses_result

	var normalized := {
		"schema_version": SCHEMA_VERSION,
		"torso": torso_result["torso"],
		"limbs": limbs_result["limbs"],
		"collision_margin_m": collision_margin_result["value"],
		"contact_material": contact_result["contact_material"],
		"body_dynamics": dynamics_result["body_dynamics"],
		"joint_limits": limits_result["joint_limits"],
		"motor_impulses": impulses_result["motor_impulses"],
	}
	var geometry_result := _validate_geometry(normalized)
	if not bool(geometry_result.get("ok", false)):
		return geometry_result
	return {
		"ok": true,
		"fixture_spec": normalized,
		"fixture_spec_sha256": CanonicalJsonScript.sha256(normalized),
		"world_build_count": 0,
	}


static func verify(fixture_spec: Dictionary, expected_sha256: String) -> Dictionary:
	var compiled := compile(fixture_spec)
	if not bool(compiled.get("ok", false)):
		return compiled
	var actual_sha256 := String(compiled["fixture_spec_sha256"])
	if (
		not expected_sha256.begins_with("sha256:")
		or expected_sha256.length() != 71
		or expected_sha256 != actual_sha256
	):
		return {
			"ok": false,
			"failure_code": "FIXTURE_SPEC_DIGEST_MISMATCH",
			"expected_sha256": expected_sha256,
			"actual_sha256": actual_sha256,
			"world_build_count": 0,
		}
	return compiled


static func vector3_from_array(value: Variant) -> Vector3:
	assert(typeof(value) == TYPE_ARRAY and (value as Array).size() == 3)
	var components: Array = value
	return Vector3(
		float(components[0]),
		float(components[1]),
		float(components[2]),
	)


static func _reference_limb(limb_id: String, longitudinal_m: float, lateral_m: float) -> Dictionary:
	return {
		"limb_id": limb_id,
		"hip_offset_from_torso_center_m": [longitudinal_m, -0.05, lateral_m],
		"upper_mass_kg": 0.25,
		"distal_mass_kg": 0.18,
		"upper_length_m": 0.18,
		"lower_length_m": 0.17,
		"upper_cross_section_m": [0.045, 0.045],
		"foot_radius_m": 0.04,
	}


static func _normalize_torso(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("INVALID_TORSO_SPEC", "torso")
	var source: Dictionary = value
	var keys_result := _validate_exact_keys(source, TORSO_KEYS, "torso")
	if not bool(keys_result.get("ok", false)):
		return keys_result
	var mass_result := _positive_number(source["mass_kg"], "torso.mass_kg")
	if not bool(mass_result.get("ok", false)):
		return mass_result
	var size_result := _number_array(source["size_m"], 3, "torso.size_m", true)
	if not bool(size_result.get("ok", false)):
		return size_result
	var center_result := _number_array(
		source["initial_center_m"], 3, "torso.initial_center_m", false
	)
	if not bool(center_result.get("ok", false)):
		return center_result
	if float(center_result["value"][1]) <= 0.0:
		return _failure("INVALID_INITIAL_TORSO_HEIGHT", "torso.initial_center_m")
	return {
		"ok": true,
		"torso":
		{
			"mass_kg": mass_result["value"],
			"size_m": size_result["value"],
			"initial_center_m": center_result["value"],
		},
	}


static func _normalize_limbs(
	value: Variant,
	torso: Dictionary,
	collision_margin_value: Variant,
) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return _failure("INVALID_LIMB_ARRAY", "limbs")
	var source: Array = value
	if source.size() != REFERENCE_LIMB_IDS.size():
		return _failure("ASYMMETRIC_LIMB_OMISSION", "limbs")
	var normalized: Array = []
	for index in range(source.size()):
		var limb_result := _normalize_limb(source[index], REFERENCE_LIMB_IDS[index])
		if not bool(limb_result.get("ok", false)):
			return limb_result
		normalized.append(limb_result["limb"])
	var collision_margin_result := _positive_number(collision_margin_value, "collision_margin_m")
	if not bool(collision_margin_result.get("ok", false)):
		return collision_margin_result
	var torso_size: Array = torso["size_m"]
	for limb_value in normalized:
		var limb: Dictionary = limb_value
		var hip_offset: Array = limb["hip_offset_from_torso_center_m"]
		if absf(float(hip_offset[1])) > float(torso_size[1]) * 0.5:
			return _failure("HIP_OUTSIDE_TORSO_HEIGHT", "%s.hip_offset" % limb["limb_id"])
	for left_index in range(normalized.size()):
		var left_offset: Array = normalized[left_index]["hip_offset_from_torso_center_m"]
		for right_index in range(left_index + 1, normalized.size()):
			var right_offset: Array = normalized[right_index]["hip_offset_from_torso_center_m"]
			if left_offset == right_offset:
				return _failure("DUPLICATE_HIP_LOCATION", "limbs")
	return {
		"ok": true,
		"limbs": normalized,
	}


static func _normalize_limb(value: Variant, expected_limb_id: String) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("INVALID_LIMB_SPEC", expected_limb_id)
	var source: Dictionary = value
	var keys_result := _validate_exact_keys(source, LIMB_KEYS, expected_limb_id)
	if not bool(keys_result.get("ok", false)):
		return keys_result
	if typeof(source["limb_id"]) != TYPE_STRING:
		return _failure("INVALID_LIMB_ID", expected_limb_id)
	if String(source["limb_id"]) != expected_limb_id:
		return _failure("NONREFERENCE_CONSTRUCTION_ORDER", "limbs")
	var offset_result := _number_array(
		source["hip_offset_from_torso_center_m"],
		3,
		"%s.hip_offset_from_torso_center_m" % expected_limb_id,
		false,
	)
	if not bool(offset_result.get("ok", false)):
		return offset_result
	var cross_section_result := _number_array(
		source["upper_cross_section_m"],
		2,
		"%s.upper_cross_section_m" % expected_limb_id,
		true,
	)
	if not bool(cross_section_result.get("ok", false)):
		return cross_section_result
	var normalized := {
		"limb_id": expected_limb_id,
		"hip_offset_from_torso_center_m": offset_result["value"],
		"upper_cross_section_m": cross_section_result["value"],
	}
	for key_value in [
		"upper_mass_kg",
		"distal_mass_kg",
		"upper_length_m",
		"lower_length_m",
		"foot_radius_m",
	]:
		var key := String(key_value)
		var number_result := _positive_number(source[key], "%s.%s" % [expected_limb_id, key])
		if not bool(number_result.get("ok", false)):
			return number_result
		normalized[key] = number_result["value"]
	return {
		"ok": true,
		"limb": normalized,
	}


static func _normalize_contact_material(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("INVALID_CONTACT_MATERIAL", "contact_material")
	var source: Dictionary = value
	var keys_result := _validate_exact_keys(source, CONTACT_MATERIAL_KEYS, "contact_material")
	if not bool(keys_result.get("ok", false)):
		return keys_result
	var friction_result := _nonnegative_number(source["friction"], "contact_material.friction")
	if not bool(friction_result.get("ok", false)):
		return friction_result
	var bounce_result := _nonnegative_number(source["bounce"], "contact_material.bounce")
	if not bool(bounce_result.get("ok", false)):
		return bounce_result
	if float(bounce_result["value"]) > 1.0:
		return _failure("INVALID_CONTACT_BOUNCE", "contact_material.bounce")
	for key_value in ["rough", "absorbent"]:
		if typeof(source[key_value]) != TYPE_BOOL:
			return _failure("INVALID_BOOLEAN_FIELD", "contact_material.%s" % key_value)
	return {
		"ok": true,
		"contact_material":
		{
			"friction": friction_result["value"],
			"rough": bool(source["rough"]),
			"bounce": bounce_result["value"],
			"absorbent": bool(source["absorbent"]),
		},
	}


static func _normalize_body_dynamics(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("INVALID_BODY_DYNAMICS", "body_dynamics")
	var source: Dictionary = value
	var keys_result := _validate_exact_keys(source, BODY_DYNAMICS_KEYS, "body_dynamics")
	if not bool(keys_result.get("ok", false)):
		return keys_result
	for key_value in ["can_sleep", "continuous_collision_detection"]:
		if typeof(source[key_value]) != TYPE_BOOL:
			return _failure("INVALID_BOOLEAN_FIELD", "body_dynamics.%s" % key_value)
	var linear_result := _nonnegative_number(source["linear_damp"], "body_dynamics.linear_damp")
	if not bool(linear_result.get("ok", false)):
		return linear_result
	var angular_result := _nonnegative_number(source["angular_damp"], "body_dynamics.angular_damp")
	if not bool(angular_result.get("ok", false)):
		return angular_result
	for key_value in ["collision_layer", "collision_mask", "maximum_reported_contacts"]:
		if typeof(source[key_value]) != TYPE_INT or int(source[key_value]) < 0:
			return _failure("INVALID_NONNEGATIVE_INTEGER_FIELD", "body_dynamics.%s" % key_value)
	if int(source["collision_layer"]) == 0:
		return _failure("EMPTY_COLLISION_LAYER", "body_dynamics.collision_layer")
	if int(source["maximum_reported_contacts"]) < 1:
		return _failure(
			"INVALID_MAXIMUM_REPORTED_CONTACTS",
			"body_dynamics.maximum_reported_contacts",
		)
	return {
		"ok": true,
		"body_dynamics":
		{
			"can_sleep": bool(source["can_sleep"]),
			"continuous_collision_detection": bool(source["continuous_collision_detection"]),
			"linear_damp": linear_result["value"],
			"angular_damp": angular_result["value"],
			"collision_layer": int(source["collision_layer"]),
			"collision_mask": int(source["collision_mask"]),
			"maximum_reported_contacts": int(source["maximum_reported_contacts"]),
		},
	}


static func _normalize_joint_limits(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("INVALID_JOINT_LIMITS", "joint_limits")
	var source: Dictionary = value
	var keys_result := _validate_exact_keys(source, JOINT_LIMIT_KEYS, "joint_limits")
	if not bool(keys_result.get("ok", false)):
		return keys_result
	var normalized: Dictionary = {}
	for key_value in JOINT_LIMIT_KEYS:
		var key := String(key_value)
		var number_result := _finite_number(source[key], "joint_limits.%s" % key)
		if not bool(number_result.get("ok", false)):
			return number_result
		normalized[key] = number_result["value"]
	if (
		float(normalized["hip_lower_rad"]) >= float(normalized["hip_upper_rad"])
		or float(normalized["hip_lower_rad"]) > 0.0
		or float(normalized["hip_upper_rad"]) < 0.0
	):
		return _failure("INVALID_HIP_LIMITS", "joint_limits")
	if (
		float(normalized["knee_lower_rad"]) >= float(normalized["knee_upper_rad"])
		or float(normalized["knee_lower_rad"]) > 0.0
		or float(normalized["knee_upper_rad"]) < 0.0
	):
		return _failure("INVALID_KNEE_LIMITS", "joint_limits")
	for key_value in ["bias", "relaxation"]:
		var key := String(key_value)
		if float(normalized[key]) < 0.0 or float(normalized[key]) > 1.0:
			return _failure("INVALID_JOINT_SOLVER_PARAMETER", "joint_limits.%s" % key)
	return {
		"ok": true,
		"joint_limits": normalized,
	}


static func _normalize_motor_impulses(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("INVALID_MOTOR_IMPULSES", "motor_impulses")
	var source: Dictionary = value
	var keys_result := _validate_exact_keys(source, MOTOR_IMPULSE_KEYS, "motor_impulses")
	if not bool(keys_result.get("ok", false)):
		return keys_result
	var normalized: Dictionary = {}
	for key_value in MOTOR_IMPULSE_KEYS:
		var key := String(key_value)
		var number_result := _positive_number(source[key], "motor_impulses.%s" % key)
		if not bool(number_result.get("ok", false)):
			return number_result
		normalized[key] = number_result["value"]
	return {
		"ok": true,
		"motor_impulses": normalized,
	}


static func _validate_geometry(spec: Dictionary) -> Dictionary:
	var collision_margin_m := float(spec["collision_margin_m"])
	var torso: Dictionary = spec["torso"]
	var torso_center: Array = torso["initial_center_m"]
	var torso_size: Array = torso["size_m"]
	for limb_value in spec["limbs"]:
		var limb: Dictionary = limb_value
		var limb_id := String(limb["limb_id"])
		var hip_offset: Array = limb["hip_offset_from_torso_center_m"]
		var upper_cross_section: Array = limb["upper_cross_section_m"]
		var upper_length_m := float(limb["upper_length_m"])
		var foot_radius_m := float(limb["foot_radius_m"])
		if maxf(float(upper_cross_section[0]), float(upper_cross_section[1])) >= upper_length_m:
			return _failure("INVALID_UPPER_SEGMENT_PROPORTION", limb_id)
		if (
			collision_margin_m
			>= minf(
				foot_radius_m,
				minf(float(upper_cross_section[0]), float(upper_cross_section[1])) * 0.5,
			)
		):
			return _failure("EXCESSIVE_COLLISION_MARGIN", limb_id)
		if absf(float(hip_offset[1])) > float(torso_size[1]) * 0.5:
			return _failure("HIP_OUTSIDE_TORSO_HEIGHT", limb_id)
		var foot_center_height_m := (
			float(torso_center[1])
			+ float(hip_offset[1])
			- upper_length_m
			- float(limb["lower_length_m"])
		)
		if foot_center_height_m + collision_margin_m < foot_radius_m:
			return _failure("INITIAL_FOOT_INTERPENETRATES_FLOOR", limb_id)
	return {"ok": true}


static func _scaled_number_array(value: Array, scale: float) -> Array:
	var scaled: Array = []
	for component_value in value:
		scaled.append(float(component_value) * scale)
	return scaled


static func _validate_exact_keys(
	source: Dictionary,
	allowed_keys: Array,
	scope: String,
) -> Dictionary:
	for key_value in source.keys():
		if typeof(key_value) != TYPE_STRING or not allowed_keys.has(String(key_value)):
			return _failure("UNKNOWN_FIXTURE_SPEC_FIELD", "%s.%s" % [scope, str(key_value)])
	for key_value in allowed_keys:
		var key := String(key_value)
		if not source.has(key):
			return _failure("MISSING_FIXTURE_SPEC_FIELD", "%s.%s" % [scope, key])
	return {"ok": true}


static func _number_array(
	value: Variant,
	expected_size: int,
	field: String,
	require_positive: bool,
) -> Dictionary:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != expected_size:
		return _failure("INVALID_NUMERIC_ARRAY", field)
	var normalized: Array = []
	for component_value in value:
		var component_result := (
			_positive_number(component_value, field)
			if require_positive
			else _finite_number(component_value, field)
		)
		if not bool(component_result.get("ok", false)):
			return component_result
		normalized.append(component_result["value"])
	return {
		"ok": true,
		"value": normalized,
	}


static func _finite_number(value: Variant, field: String) -> Dictionary:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return _failure("INVALID_NUMERIC_FIELD", field)
	var normalized := float(value)
	if not is_finite(normalized):
		return _failure("NONFINITE_NUMERIC_FIELD", field)
	return {
		"ok": true,
		"value": normalized,
	}


static func _positive_number(value: Variant, field: String) -> Dictionary:
	var result := _finite_number(value, field)
	if not bool(result.get("ok", false)):
		return result
	if float(result["value"]) <= 0.0:
		return _failure("NONPOSITIVE_NUMERIC_FIELD", field)
	return result


static func _nonnegative_number(value: Variant, field: String) -> Dictionary:
	var result := _finite_number(value, field)
	if not bool(result.get("ok", false)):
		return result
	if float(result["value"]) < 0.0:
		return _failure("NEGATIVE_NUMERIC_FIELD", field)
	return result


static func _failure(failure_code: String, field: String) -> Dictionary:
	return {
		"ok": false,
		"failure_code": failure_code,
		"field": field,
		"world_build_count": 0,
	}
