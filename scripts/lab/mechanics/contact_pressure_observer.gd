class_name LabContactPressureObserver
extends RefCounted

## Per-step raw-contact pressure observation for L1.4 and later foot cells.
##
## Godot/Jolt exposes a predicted contact impulse estimate, not a continuous
## force transducer. For a step dt and contact normal n_i this adapter reports:
##
##     w_i = max(J_i dot n_i, 0)
##     predicted_normal_load = sum(w_i) / dt
##     predicted_CoP = sum(w_i p_i) / sum(w_i)
##
## The quality label stays explicit so later mechanics reconstruction cannot
## silently treat this channel as an exact solved contact wrench.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const SupportGeometryScript := preload(
	"res://scripts/lab/mechanics/support_geometry.gd")

const SCHEMA_VERSION := "contact_pressure_observation_v1"
const REQUIRED_IMPULSE_QUALITY := "jolt_predicted_estimate"


static func observe_raw_points(
		raw_contacts: Array,
		physics_step_id: int,
		counterparty_semantic_id: String,
		step_s: float,
		expected_normal_world: Vector3) -> Dictionary:
	var reasons: Array[String] = []
	if physics_step_id < 0:
		reasons.append("PRESSURE_STEP_ID_INVALID")
	if counterparty_semantic_id.is_empty():
		reasons.append("PRESSURE_COUNTERPARTY_ID_INVALID")
	if not is_finite(step_s) or step_s <= 0.0:
		reasons.append("PRESSURE_STEP_DURATION_INVALID")
	if not expected_normal_world.is_finite() \
			or expected_normal_world.length_squared() <= 1.0e-12:
		reasons.append("PRESSURE_EXPECTED_NORMAL_INVALID")
	if not reasons.is_empty():
		return _invalid(reasons)

	var expected_normal := expected_normal_world.normalized()
	var cop_samples: Array = []
	var impulse_sum := Vector3.ZERO
	var normal_impulse_sum := 0.0
	var minimum_normal_alignment := 1.0
	var point_min := Vector3(INF, INF, INF)
	var point_max := Vector3(-INF, -INF, -INF)
	var positive_weight_count := 0
	for index in raw_contacts.size():
		var raw_value: Variant = raw_contacts[index]
		if not raw_value is Dictionary:
			reasons.append("PRESSURE_RAW_CONTACT_INVALID:%d" % index)
			continue
		var raw: Dictionary = raw_value
		if int(raw.get("physics_step_id", -1)) != physics_step_id:
			continue
		if String(raw.get("counterparty_semantic_id", "")) \
				!= counterparty_semantic_id:
			continue
		if not bool(raw.get("finite", false)):
			reasons.append("PRESSURE_RAW_CONTACT_NONFINITE:%d" % index)
			continue
		if String(raw.get("impulse_quality", "")) \
				!= REQUIRED_IMPULSE_QUALITY:
			reasons.append("PRESSURE_IMPULSE_QUALITY_INVALID:%d" % index)
			continue
		var point_value: Variant = raw.get("point_world")
		var normal_value: Variant = raw.get("normal_world")
		var impulse_value: Variant = raw.get("impulse_world_ns")
		if not point_value is Vector3 \
				or not normal_value is Vector3 \
				or not impulse_value is Vector3 \
				or not (point_value as Vector3).is_finite() \
				or not (normal_value as Vector3).is_finite() \
				or not (impulse_value as Vector3).is_finite() \
				or (normal_value as Vector3).length_squared() <= 1.0e-12:
			reasons.append("PRESSURE_RAW_VECTOR_INVALID:%d" % index)
			continue
		var point: Vector3 = point_value
		var normal: Vector3 = (normal_value as Vector3).normalized()
		var impulse: Vector3 = impulse_value
		var normal_alignment := normal.dot(expected_normal)
		minimum_normal_alignment = minf(
			minimum_normal_alignment, normal_alignment)
		if normal_alignment < 0.999:
			reasons.append("PRESSURE_NORMAL_FRAME_MISMATCH:%d" % index)
			continue
		var normal_weight := maxf(impulse.dot(normal), 0.0)
		if normal_weight > 0.0:
			positive_weight_count += 1
		cop_samples.append({
			"point_world": point,
			"normal_weight": normal_weight,
		})
		impulse_sum += impulse
		normal_impulse_sum += normal_weight
		point_min = Vector3(
			minf(point_min.x, point.x),
			minf(point_min.y, point.y),
			minf(point_min.z, point.z))
		point_max = Vector3(
			maxf(point_max.x, point.x),
			maxf(point_max.y, point.y),
			maxf(point_max.z, point.z))
	if cop_samples.is_empty():
		reasons.append("PRESSURE_NO_MATCHING_CONTACTS")
	if not reasons.is_empty():
		return _invalid(reasons)
	var cop: Dictionary = SupportGeometryScript.center_of_pressure(cop_samples)
	if not bool(cop.get("finite", false)):
		return _invalid(["PRESSURE_COP_UNAVAILABLE"])
	var center: Vector3 = cop["center_of_pressure_world"]
	var predicted_normal_load := normal_impulse_sum / step_s
	return FrozenValueScript.snapshot({
		"schema_version": SCHEMA_VERSION,
		"observation_valid": (
			center.is_finite()
			and impulse_sum.is_finite()
			and is_finite(predicted_normal_load)),
		"invalid_reasons": [],
		"physics_step_id": physics_step_id,
		"counterparty_semantic_id": counterparty_semantic_id,
		"raw_contact_count": cop_samples.size(),
		"positive_weight_contact_count": positive_weight_count,
		"center_of_pressure_world_m": center,
		"total_predicted_impulse_world_ns": impulse_sum,
		"total_predicted_normal_impulse_ns": normal_impulse_sum,
		"predicted_normal_load_n": predicted_normal_load,
		"minimum_normal_alignment_dot": minimum_normal_alignment,
		"contact_point_min_world_m": point_min,
		"contact_point_max_world_m": point_max,
		"impulse_quality": REQUIRED_IMPULSE_QUALITY,
		"pressure_quality": "impulse_weighted_jolt_predicted_estimate_v1",
		"continuous_force_claim": false,
	})


static func _invalid(reasons: Array[String]) -> Dictionary:
	return FrozenValueScript.snapshot({
		"schema_version": SCHEMA_VERSION,
		"observation_valid": false,
		"invalid_reasons": reasons,
		"center_of_pressure_world_m": null,
		"predicted_normal_load_n": null,
		"pressure_quality": "unavailable",
		"continuous_force_claim": false,
	})
