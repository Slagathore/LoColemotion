class_name LabExternalContactImpulseReconstructor
extends RefCounted

## Reconstructs whole-system unknown external impulse from post-step momentum.
##
##     J_unknown = P_after - P_before - sum(J_known_external)
##
## For a creature/stack whose only known external field is gravity, the unknown
## term is the net environment-contact impulse. This closes the transmission
## blindness of per-contact Jolt predicted estimates without pretending it can
## allocate the reconstructed wrench among multiple feet or contact points.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA_VERSION := "external_contact_impulse_reconstruction_v1"


static func reconstruct(
		previous_post_step_bodies: Array,
		current_post_step_bodies: Array,
		step_s: float,
		known_external_impulse_world_ns: Vector3,
		support_normal_world: Vector3) -> Dictionary:
	var reasons: Array[String] = []
	if not is_finite(step_s) or step_s <= 0.0:
		reasons.append("EXTERNAL_IMPULSE_STEP_INVALID")
	if not known_external_impulse_world_ns.is_finite():
		reasons.append("KNOWN_EXTERNAL_IMPULSE_NONFINITE")
	if not support_normal_world.is_finite() \
			or support_normal_world.length_squared() <= 1.0e-12:
		reasons.append("SUPPORT_NORMAL_INVALID")
	var previous := _aggregate(previous_post_step_bodies, "PREVIOUS")
	var current := _aggregate(current_post_step_bodies, "CURRENT")
	reasons.append_array(previous["reasons"] as Array[String])
	reasons.append_array(current["reasons"] as Array[String])
	if bool(previous.get("valid", false)) \
			and bool(current.get("valid", false)) \
			and previous["body_ids"] != current["body_ids"]:
		reasons.append("EXTERNAL_IMPULSE_BODY_SET_MISMATCH")
	if not reasons.is_empty():
		return _invalid(reasons)
	var momentum_before: Vector3 = previous["linear_momentum_world_ns"]
	var momentum_after: Vector3 = current["linear_momentum_world_ns"]
	var momentum_delta := momentum_after - momentum_before
	var unknown_impulse := momentum_delta - known_external_impulse_world_ns
	var normal := support_normal_world.normalized()
	var normal_impulse := unknown_impulse.dot(normal)
	var tangential_impulse := unknown_impulse - normal_impulse * normal
	var normal_load := normal_impulse / step_s
	return FrozenValueScript.snapshot({
		"schema_version": SCHEMA_VERSION,
		"reconstruction_valid": (
			unknown_impulse.is_finite()
			and tangential_impulse.is_finite()
			and is_finite(normal_load)),
		"invalid_reasons": [],
		"body_ids": current["body_ids"],
		"total_mass_kg": float(current["total_mass_kg"]),
		"step_s": step_s,
		"linear_momentum_before_world_ns": momentum_before,
		"linear_momentum_after_world_ns": momentum_after,
		"linear_momentum_delta_world_ns": momentum_delta,
		"known_external_impulse_world_ns": known_external_impulse_world_ns,
		"reconstructed_unknown_external_impulse_world_ns": unknown_impulse,
		"support_normal_world": normal,
		"reconstructed_normal_impulse_ns": normal_impulse,
		"reconstructed_tangential_impulse_world_ns": tangential_impulse,
		"reconstructed_step_average_normal_load_n": normal_load,
		"reconstruction_quality": "post_step_whole_system_momentum_balance_v1",
		"contact_allocation_available": false,
		"center_of_pressure_available": false,
		"allocation_unavailable_reason": (
			"NET_EXTERNAL_IMPULSE_DOES_NOT_IDENTIFY_PER_CONTACT_ALLOCATION"),
	})


static func _aggregate(samples: Array, label: String) -> Dictionary:
	var reasons: Array[String] = []
	var ids: Array[String] = []
	var seen: Dictionary = {}
	var total_mass := 0.0
	var momentum := Vector3.ZERO
	for index in samples.size():
		var sample_value: Variant = samples[index]
		if not sample_value is Dictionary:
			reasons.append("%s_BODY_SAMPLE_INVALID:%d" % [label, index])
			continue
		var sample: Dictionary = sample_value
		var body_id := String(sample.get("body_id", ""))
		var mass := float(sample.get("mass_kg", NAN))
		var velocity_value: Variant = sample.get("linear_velocity_world_mps")
		if body_id.is_empty() or seen.has(body_id):
			reasons.append("%s_BODY_ID_INVALID:%d" % [label, index])
			continue
		if not is_finite(mass) or mass <= 0.0 \
				or not velocity_value is Vector3 \
				or not (velocity_value as Vector3).is_finite():
			reasons.append("%s_BODY_CHANNEL_INVALID:%s" % [label, body_id])
			continue
		seen[body_id] = true
		ids.append(body_id)
		total_mass += mass
		momentum += mass * (velocity_value as Vector3)
	ids.sort()
	if samples.is_empty():
		reasons.append("%s_BODY_SET_EMPTY" % label)
	return {
		"valid": reasons.is_empty()
			and total_mass > 0.0
			and momentum.is_finite(),
		"reasons": reasons,
		"body_ids": ids,
		"total_mass_kg": total_mass,
		"linear_momentum_world_ns": momentum,
	}


static func _invalid(reasons: Array[String]) -> Dictionary:
	return FrozenValueScript.snapshot({
		"schema_version": SCHEMA_VERSION,
		"reconstruction_valid": false,
		"invalid_reasons": reasons,
		"reconstructed_unknown_external_impulse_world_ns": null,
		"reconstructed_step_average_normal_load_n": null,
		"contact_allocation_available": false,
		"center_of_pressure_available": false,
	})
