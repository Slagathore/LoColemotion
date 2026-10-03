class_name LabContactCanonicalizer
extends RefCounted

## BR3A raw-point to stable convex-manifold contact patches.
##
## Godot/Jolt's callback index is not a contact identity; it changes whenever
## the manifold is rebuilt.  For the L1.0-L1.7 convex fixture scope, one stable
## patch is identified by the semantic body/shape pair. All raw manifold points
## for that pair are aggregated.  The identity intentionally does not include
## callback sequence, raw point index, world position, or runtime instance ID.
##
## Scope boundary: a concave shape pair can contain multiple disconnected
## patches. This v1 contract must not be promoted for that case; L1.8/high
## contact-discretization work needs a versioned feature/cluster identity.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const RAW_SCHEMA_VERSION := "raw_contact_point_v2"
const PATCH_SCHEMA_VERSION := "contact_patch_v1"
const RESULT_SCHEMA_VERSION := "contact_canonicalization_v1"
const IDENTITY_SCOPE := "single_convex_manifold_per_shape_pair_v1"
const VALID_SAMPLE_PHASES := ["integrate_callback", "post_step"]
const NORMAL_LENGTH_EPSILON := 1.0e-8
const MINIMUM_CLUSTER_NORMAL_DOT := 0.95
const NORMAL_IMPULSE_EPSILON_N_S := 1.0e-7


static func canonicalize(
		raw_contacts: Array,
		capacity_observation: Dictionary,
		frame_context: Dictionary) -> Dictionary:
	var reasons: Array[String] = []
	if not bool(capacity_observation.get("finite", false)):
		reasons.append("CONTACT_CAPACITY_OBSERVATION_INVALID")
	if int(capacity_observation.get("observed_count", -1)) \
			!= raw_contacts.size():
		reasons.append("CONTACT_CAPACITY_COUNT_MISMATCH")
	var expected_body_id := String(
		capacity_observation.get("body_id", ""))
	var context_result := _validate_frame_context(
		frame_context, expected_body_id)
	reasons.append_array(context_result["reasons"] as Array[String])

	var identity: Dictionary = context_result["frame_identity"]
	var groups: Dictionary = {}
	var raw_ids: Dictionary = {}
	for index in raw_contacts.size():
		var raw_value: Variant = raw_contacts[index]
		if not raw_value is Dictionary:
			reasons.append("RAW_CONTACT_NOT_DICTIONARY:%d" % index)
			continue
		var raw: Dictionary = raw_value
		var validation := _validate_raw_contact(
			raw, expected_body_id, index)
		reasons.append_array(validation["reasons"] as Array[String])
		if not bool(validation["valid"]):
			continue
		var raw_id := String(raw["raw_contact_observation_id"])
		if raw_ids.has(raw_id):
			reasons.append("RAW_CONTACT_OBSERVATION_ID_DUPLICATE")
			continue
		raw_ids[raw_id] = true
		var current_identity: Dictionary = validation["frame_identity"]
		if current_identity != identity:
			reasons.append("RAW_CONTACTS_SPAN_FRAME_IDENTITY")
			continue
		var patch_identity: Dictionary = validation["patch_identity"]
		var patch_id := CanonicalJsonScript.sha256({
			"identity_scope": IDENTITY_SCOPE,
			"patch_identity": patch_identity,
		})
		if not groups.has(patch_id):
			groups[patch_id] = {
				"identity": patch_identity,
				"raw_contacts": [],
			}
		(groups[patch_id]["raw_contacts"] as Array).append(raw)

	if not reasons.is_empty():
		return FrozenValueScript.snapshot({
			"schema_version": RESULT_SCHEMA_VERSION,
			"ok": false,
			"finite": false,
			"invalid_reasons": reasons,
			"frame_identity": identity if not identity.is_empty() else null,
			"raw_contact_count": raw_contacts.size(),
			"canonical_patch_count": 0,
			"patches": [],
			"identity_scope": IDENTITY_SCOPE,
		})

	var patch_ids: Array = groups.keys()
	patch_ids.sort()
	var patches: Array = []
	for patch_id_value in patch_ids:
		var patch_id := String(patch_id_value)
		var group: Dictionary = groups[patch_id]
		var patch_result := _aggregate_patch(
			patch_id,
			group["identity"],
			group["raw_contacts"],
			identity)
		if not bool(patch_result["ok"]):
			reasons.append_array(
				patch_result["invalid_reasons"] as Array[String])
		else:
			patches.append(patch_result["patch"])
	if not reasons.is_empty():
		return FrozenValueScript.snapshot({
			"schema_version": RESULT_SCHEMA_VERSION,
			"ok": false,
			"finite": false,
			"invalid_reasons": reasons,
			"frame_identity": identity if not identity.is_empty() else null,
			"raw_contact_count": raw_contacts.size(),
			"canonical_patch_count": 0,
			"patches": [],
			"identity_scope": IDENTITY_SCOPE,
		})
	return FrozenValueScript.snapshot({
		"schema_version": RESULT_SCHEMA_VERSION,
		"ok": true,
		"finite": true,
		"invalid_reasons": [],
		"frame_identity": identity if not identity.is_empty() else null,
		"raw_contact_count": raw_contacts.size(),
		"canonical_patch_count": patches.size(),
		"patches": patches,
		"identity_scope": IDENTITY_SCOPE,
	})


static func _validate_raw_contact(
		raw: Dictionary,
		expected_body_id: String,
		index: int) -> Dictionary:
	var reasons: Array[String] = []
	if String(raw.get("schema_version", "")) != RAW_SCHEMA_VERSION:
		reasons.append("RAW_CONTACT_SCHEMA_UNSUPPORTED:%d" % index)
	var frame_identity := {}
	for field in [
		"run_id",
		"capture_stream_id",
		"observer_profile_id",
		"observer_adapter_id",
	]:
		var value: Variant = raw.get(field)
		if not _stable_name_value(value):
			reasons.append("RAW_CONTACT_%s_INVALID:%d" % [
				field.to_upper(), index])
		else:
			frame_identity[field] = String(value)
	if typeof(raw.get("physics_step_id")) != TYPE_INT \
			or int(raw.get("physics_step_id", -1)) < 0:
		reasons.append("RAW_CONTACT_STEP_INVALID:%d" % index)
	else:
		frame_identity["physics_step_id"] = int(raw["physics_step_id"])
	if typeof(raw.get("capture_epoch")) != TYPE_INT \
			or int(raw.get("capture_epoch", -1)) < 0:
		reasons.append("RAW_CONTACT_EPOCH_INVALID:%d" % index)
	else:
		frame_identity["capture_epoch"] = int(raw["capture_epoch"])
	var phase: Variant = raw.get("sample_phase")
	if not _stable_name_value(phase) \
			or String(phase) not in VALID_SAMPLE_PHASES:
		reasons.append("RAW_CONTACT_PHASE_INVALID:%d" % index)
	else:
		frame_identity["sample_phase"] = String(phase)

	for field in [
		"raw_contact_observation_id",
		"observed_body_id",
		"observed_creature_id",
		"observed_role",
		"observed_shape_semantic_id",
		"counterparty_kind",
		"counterparty_semantic_id",
		"counterparty_shape_semantic_id",
		"surface_tag",
		"impulse_quality",
	]:
		if not _stable_name_value(raw.get(field)):
			reasons.append("RAW_CONTACT_%s_INVALID:%d" % [
				field.to_upper(), index])
	if String(raw.get("observed_body_id", "")) != expected_body_id:
		reasons.append("RAW_CONTACT_CAPACITY_BODY_MISMATCH:%d" % index)
	for field in ["observed_shape_index", "counterparty_shape_index"]:
		if typeof(raw.get(field)) != TYPE_INT or int(raw[field]) < 0:
			reasons.append("RAW_CONTACT_%s_INVALID:%d" % [
				field.to_upper(), index])
	if typeof(raw.get("surface_layer")) != TYPE_INT \
			or int(raw.get("surface_layer", 0)) <= 0:
		reasons.append("RAW_CONTACT_SURFACE_LAYER_INVALID:%d" % index)
	var counterparty_kind := String(raw.get("counterparty_kind", ""))
	if counterparty_kind not in ["environment", "creature"]:
		reasons.append("RAW_CONTACT_COUNTERPARTY_KIND_UNSUPPORTED:%d" % index)
	var counterparty_creature: Variant = raw.get("counterparty_creature_id")
	if counterparty_kind == "creature" \
			and not _stable_name_value(counterparty_creature):
		reasons.append("RAW_CONTACT_COUNTERPARTY_CREATURE_ID_INVALID:%d" % index)
	if counterparty_kind == "environment" and counterparty_creature != null:
		reasons.append("RAW_CONTACT_ENVIRONMENT_CREATURE_ID_MUST_BE_NULL:%d" % index)

	var point := _vector3(raw.get("point_world"))
	var normal := _vector3(raw.get("normal_world"))
	var impulse := _vector3(raw.get("impulse_world_ns"))
	var relative_velocity := _vector3(
		raw.get("relative_velocity_world_mps"))
	if not point.is_finite():
		reasons.append("RAW_CONTACT_POINT_NONFINITE:%d" % index)
	if not bool(raw.get("normal_available", false)) \
			or not normal.is_finite() \
			or normal.length_squared() <= NORMAL_LENGTH_EPSILON:
		reasons.append("RAW_CONTACT_NORMAL_UNAVAILABLE:%d" % index)
	if not impulse.is_finite():
		reasons.append("RAW_CONTACT_IMPULSE_NONFINITE:%d" % index)
	elif normal.is_finite() \
			and normal.length_squared() > NORMAL_LENGTH_EPSILON \
			and impulse.dot(normal.normalized()) \
				< -NORMAL_IMPULSE_EPSILON_N_S:
		reasons.append("RAW_CONTACT_NORMAL_IMPULSE_NEGATIVE:%d" % index)
	if not relative_velocity.is_finite():
		reasons.append("RAW_CONTACT_RELATIVE_VELOCITY_NONFINITE:%d" % index)
	if not bool(raw.get("finite", false)):
		reasons.append("RAW_CONTACT_NOT_FINITE:%d" % index)

	var patch_identity := {
		"observed_creature_id": String(raw.get("observed_creature_id", "")),
		"observed_body_id": String(raw.get("observed_body_id", "")),
		"observed_shape_semantic_id": String(
			raw.get("observed_shape_semantic_id", "")),
		"counterparty_kind": counterparty_kind,
		"counterparty_semantic_id": String(
			raw.get("counterparty_semantic_id", "")),
		"counterparty_shape_semantic_id": String(
			raw.get("counterparty_shape_semantic_id", "")),
	}
	return {
		"valid": reasons.is_empty(),
		"reasons": reasons,
		"frame_identity": frame_identity,
		"patch_identity": patch_identity,
	}


static func _aggregate_patch(
		patch_id: String,
		patch_identity: Dictionary,
		raw_contacts: Array,
		frame_identity: Dictionary) -> Dictionary:
	var reasons: Array[String] = []
	var first: Dictionary = raw_contacts[0]
	var point_sum := Vector3.ZERO
	var normal_sum := Vector3.ZERO
	var impulse_sum := Vector3.ZERO
	var relative_velocity_sum := Vector3.ZERO
	var raw_ids: Array = []
	var reference_normal := _vector3(first["normal_world"]).normalized()
	for raw_value in raw_contacts:
		var raw: Dictionary = raw_value
		for field in [
			"observed_role",
			"observed_shape_index",
			"surface_layer",
			"surface_tag",
			"counterparty_creature_id",
			"counterparty_shape_index",
			"impulse_quality",
		]:
			if raw.get(field) != first.get(field):
				reasons.append(
					"CONTACT_PATCH_METADATA_INCOHERENT:%s" % field)
		var normal := _vector3(raw["normal_world"]).normalized()
		if normal.dot(reference_normal) < MINIMUM_CLUSTER_NORMAL_DOT:
			reasons.append("CONTACT_PATCH_NORMAL_CLUSTER_INCOHERENT")
		point_sum += _vector3(raw["point_world"])
		normal_sum += normal
		impulse_sum += _vector3(raw["impulse_world_ns"])
		relative_velocity_sum += _vector3(
			raw["relative_velocity_world_mps"])
		raw_ids.append(String(raw["raw_contact_observation_id"]))
	if normal_sum.length_squared() <= NORMAL_LENGTH_EPSILON:
		reasons.append("CONTACT_PATCH_NORMAL_SUM_DEGENERATE")
	if not reasons.is_empty():
		return {
			"ok": false,
			"invalid_reasons": reasons,
			"patch": null,
		}
	raw_ids.sort()
	var count := raw_contacts.size()
	var normal_world := normal_sum.normalized()
	var counterparty_kind := String(
		patch_identity["counterparty_kind"])
	var observed_creature := String(
		patch_identity["observed_creature_id"])
	var counterparty_creature := _stable_text(
		first.get("counterparty_creature_id"))
	var same_creature := counterparty_kind == "creature" \
		and counterparty_creature == observed_creature
	var ownership := (
		"creature_environment"
		if counterparty_kind == "environment"
		else "same_creature"
		if same_creature
		else "creature_creature")
	var average_relative_velocity := relative_velocity_sum / float(count)
	var normal_impulse_ns := impulse_sum.dot(normal_world)
	return {
		"ok": true,
		"invalid_reasons": [],
		"patch": {
			"schema_version": PATCH_SCHEMA_VERSION,
			"contact_patch_id": patch_id,
			"identity_scope": IDENTITY_SCOPE,
			"physics_step_id": int(frame_identity["physics_step_id"]),
			"capture_epoch": int(frame_identity["capture_epoch"]),
			"sample_phase": String(frame_identity["sample_phase"]),
			"run_id": String(frame_identity["run_id"]),
			"capture_stream_id": String(
				frame_identity["capture_stream_id"]),
			"observer_profile_id": String(
				frame_identity["observer_profile_id"]),
			"observer_adapter_id": String(
				frame_identity["observer_adapter_id"]),
			"contact_present": true,
			"canonical_pair_side": true,
			"ownership": ownership,
			"same_creature_contact": same_creature,
			"role": String(first["observed_role"]),
			"surface_layer": int(first["surface_layer"]),
			"surface_tag": String(first["surface_tag"]),
			"observed_creature_id": observed_creature,
			"observed_body_id": String(
				patch_identity["observed_body_id"]),
			"observed_shape_semantic_id": String(
				patch_identity["observed_shape_semantic_id"]),
			"observed_shape_index": int(first["observed_shape_index"]),
			"counterparty_kind": counterparty_kind,
			"counterparty_semantic_id": String(
				patch_identity["counterparty_semantic_id"]),
			"counterparty_shape_semantic_id": String(
				patch_identity["counterparty_shape_semantic_id"]),
			"counterparty_shape_index": int(
				first["counterparty_shape_index"]),
			"counterparty_creature_id": (
				counterparty_creature
				if counterparty_kind == "creature"
				else null),
			"point_world": point_sum / float(count),
			"normal_world": normal_world,
			"normal_available": true,
			"impulse_world_ns": impulse_sum,
			"normal_impulse_ns": normal_impulse_ns,
			"impulse_quality": String(first["impulse_quality"]),
			"relative_velocity_world_mps":
				average_relative_velocity,
			"relative_separation_velocity_mps":
				average_relative_velocity.dot(normal_world),
			"raw_contact_observation_ids": raw_ids,
			"raw_point_count": count,
			"finite": true,
		},
	}


static func _stable_name_value(value: Variant) -> bool:
	return (value is String or value is StringName) \
		and not String(value).is_empty()


static func _stable_text(value: Variant) -> String:
	return String(value) if value is String or value is StringName else ""


static func _validate_frame_context(
		context: Dictionary,
		expected_body_id: String) -> Dictionary:
	var reasons: Array[String] = []
	var identity := {}
	for field in [
		"run_id",
		"capture_stream_id",
		"observer_profile_id",
		"observer_adapter_id",
	]:
		var value: Variant = context.get(field)
		if not _stable_name_value(value):
			reasons.append("FRAME_CONTEXT_%s_INVALID" % field.to_upper())
		else:
			identity[field] = String(value)
	if typeof(context.get("physics_step_id")) != TYPE_INT \
			or int(context.get("physics_step_id", -1)) < 0:
		reasons.append("FRAME_CONTEXT_STEP_INVALID")
	else:
		identity["physics_step_id"] = int(context["physics_step_id"])
	if typeof(context.get("capture_epoch")) != TYPE_INT \
			or int(context.get("capture_epoch", -1)) < 0:
		reasons.append("FRAME_CONTEXT_EPOCH_INVALID")
	else:
		identity["capture_epoch"] = int(context["capture_epoch"])
	var phase: Variant = context.get("sample_phase")
	if not _stable_name_value(phase) \
			or String(phase) not in VALID_SAMPLE_PHASES:
		reasons.append("FRAME_CONTEXT_PHASE_INVALID")
	else:
		identity["sample_phase"] = String(phase)
	if String(context.get("body_id", "")) != expected_body_id \
			or expected_body_id.is_empty():
		reasons.append("FRAME_CONTEXT_BODY_ID_MISMATCH")
	return {
		"reasons": reasons,
		"frame_identity": identity,
	}


static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and (value as Array).size() == 3:
		var raw: Array = value
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3(INF, INF, INF)
