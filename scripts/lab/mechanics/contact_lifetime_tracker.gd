class_name LabContactLifetimeTracker
extends RefCounted

## BR3A lifetime owner for canonical convex-manifold patches.
##
## BEGIN is the first observed frame, PERSIST requires an exact next frame, and
## END is emitted on the first coherent frame where the patch is absent. A
## missing frame does not manufacture an END time: the tracker fails closed,
## clears its active set, and requires explicit reinitialization.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const INPUT_SCHEMA_VERSION := "contact_canonicalization_v1"
const RESULT_SCHEMA_VERSION := "contact_lifetime_frame_v1"

var _active: Dictionary = {}
var _identity: Dictionary = {}
var _initialized := false
var _requires_reinitialize := false


func initialize(canonical_frame: Dictionary) -> Dictionary:
	if _initialized and not _requires_reinitialize:
		return _failure(
			"CONTACT_LIFETIME_ALREADY_INITIALIZED",
			_frame_identity(canonical_frame))
	var validation := _validate_input(canonical_frame)
	if not bool(validation["valid"]):
		return _failure(
			String(validation["reason"]),
			validation["identity"])
	_active = {}
	_identity = validation["identity"]
	_initialized = true
	_requires_reinitialize = false
	return _accept_frame(canonical_frame, true)


func advance(canonical_frame: Dictionary) -> Dictionary:
	if not _initialized or _requires_reinitialize:
		return _failure(
			"CONTACT_LIFETIME_REINITIALIZATION_REQUIRED",
			_frame_identity(canonical_frame))
	var validation := _validate_input(canonical_frame)
	if not bool(validation["valid"]):
		return _break_lineage(
			String(validation["reason"]),
			validation["identity"])
	var next_identity: Dictionary = validation["identity"]
	if int(next_identity["physics_step_id"]) \
			!= int(_identity["physics_step_id"]) + 1:
		return _break_lineage(
			"CONTACT_LIFETIME_STEP_DISCONTINUITY", next_identity)
	if int(next_identity["capture_epoch"]) \
			!= int(_identity["capture_epoch"]) + 1:
		return _break_lineage(
			"CONTACT_LIFETIME_EPOCH_DISCONTINUITY", next_identity)
	for field in [
		"sample_phase",
		"run_id",
		"capture_stream_id",
		"observer_profile_id",
		"observer_adapter_id",
	]:
		if String(next_identity[field]) != String(_identity[field]):
			return _break_lineage(
				"CONTACT_LIFETIME_%s_CHANGED" % field.to_upper(),
				next_identity)
	_identity = next_identity
	return _accept_frame(canonical_frame, false)


func requires_reinitialize() -> bool:
	return _requires_reinitialize


func active_patch_count() -> int:
	return _active.size()


func _accept_frame(
		canonical_frame: Dictionary,
		is_initialization: bool) -> Dictionary:
	var patches: Array = canonical_frame.get("patches", [])
	var observed_ids: Dictionary = {}
	var output_patches: Array = []
	var events: Array = []
	for patch_value in patches:
		var patch: Dictionary = patch_value
		var patch_id := String(patch["contact_patch_id"])
		observed_ids[patch_id] = true
		var prior: Dictionary = _active.get(patch_id, {})
		var age_ticks := int(prior.get("age_ticks", 0)) + 1
		var began := prior.is_empty()
		var begin_step := (
			int(_identity["physics_step_id"])
			if began
			else int(prior["begin_step_id"]))
		var begin_epoch := (
			int(_identity["capture_epoch"])
			if began
			else int(prior["begin_capture_epoch"]))
		var tracked := {
			"age_ticks": age_ticks,
			"begin_step_id": begin_step,
			"begin_capture_epoch": begin_epoch,
			"last_step_id": int(_identity["physics_step_id"]),
			"last_capture_epoch": int(_identity["capture_epoch"]),
		}
		_active[patch_id] = tracked
		var output_patch := patch.duplicate(true)
		output_patch["lifetime"] = tracked
		output_patch["lifetime_event"] = "BEGIN" if began else "PERSIST"
		output_patches.append(output_patch)
		events.append({
			"event": "BEGIN" if began else "PERSIST",
			"contact_patch_id": patch_id,
			"physics_step_id": int(_identity["physics_step_id"]),
			"capture_epoch": int(_identity["capture_epoch"]),
			"age_ticks": age_ticks,
		})

	var prior_ids: Array = _active.keys()
	for patch_id_value in prior_ids:
		var patch_id := String(patch_id_value)
		if observed_ids.has(patch_id):
			continue
		var ended: Dictionary = _active[patch_id]
		events.append({
			"event": "END",
			"contact_patch_id": patch_id,
			"physics_step_id": int(_identity["physics_step_id"]),
			"capture_epoch": int(_identity["capture_epoch"]),
			"age_ticks": int(ended["age_ticks"]),
			"last_present_step_id": int(ended["last_step_id"]),
			"last_present_capture_epoch": int(
				ended["last_capture_epoch"]),
		})
		_active.erase(patch_id)
	output_patches.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["contact_patch_id"]) \
			< String(right["contact_patch_id"]))
	events.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_key := "%s:%s" % [
			String(left["contact_patch_id"]), String(left["event"])]
		var right_key := "%s:%s" % [
			String(right["contact_patch_id"]), String(right["event"])]
		return left_key < right_key)
	return FrozenValueScript.snapshot({
		"schema_version": RESULT_SCHEMA_VERSION,
		"ok": true,
		"finite": true,
		"initialized_this_frame": is_initialization,
		"requires_reinitialize": false,
		"frame_identity": _identity,
		"patches": output_patches,
		"events": events,
		"active_patch_count": _active.size(),
		"invalid_reasons": [],
	})


func _break_lineage(reason: String, identity: Dictionary) -> Dictionary:
	_active = {}
	_initialized = false
	_requires_reinitialize = true
	return _failure(reason, identity)


func _failure(reason: String, identity: Dictionary) -> Dictionary:
	return FrozenValueScript.snapshot({
		"schema_version": RESULT_SCHEMA_VERSION,
		"ok": false,
		"finite": false,
		"initialized_this_frame": false,
		"requires_reinitialize": _requires_reinitialize,
		"frame_identity": identity if not identity.is_empty() else null,
		"patches": [],
		"events": [],
		"active_patch_count": 0,
		"invalid_reasons": [reason],
	})


# Each return names a distinct fail-closed evidence boundary; flattening these
# into shared mutable state would make the exact diagnostic less reviewable.
# gdlint: disable=max-returns
func _validate_input(value: Dictionary) -> Dictionary:
	var identity := _frame_identity(value)
	if String(value.get("schema_version", "")) != INPUT_SCHEMA_VERSION:
		return _invalid_input(
			"CONTACT_CANONICALIZATION_SCHEMA_UNSUPPORTED", identity)
	if not bool(value.get("ok", false)) \
			or not bool(value.get("finite", false)):
		return _invalid_input(
			"CONTACT_CANONICALIZATION_INVALID", identity)
	if identity.is_empty():
		return _invalid_input("CONTACT_FRAME_IDENTITY_INVALID", identity)
	var seen: Dictionary = {}
	for patch_value in value.get("patches", []):
		if not patch_value is Dictionary:
			return _invalid_input("CONTACT_PATCH_INVALID", identity)
		var patch: Dictionary = patch_value
		var patch_id := String(patch.get("contact_patch_id", ""))
		if patch_id.is_empty() or seen.has(patch_id):
			return _invalid_input(
				"CONTACT_PATCH_ID_INVALID_OR_DUPLICATE", identity)
		seen[patch_id] = true
		for field in ["physics_step_id", "capture_epoch", "sample_phase"]:
			if patch.get(field) != identity.get(field):
				return _invalid_input(
					"CONTACT_PATCH_FRAME_IDENTITY_MISMATCH", identity)
	return {"valid": true, "reason": "", "identity": identity}
# gdlint: enable=max-returns


func _frame_identity(value: Dictionary) -> Dictionary:
	var identity_value: Variant = value.get("frame_identity")
	if not identity_value is Dictionary:
		return {}
	var identity: Dictionary = identity_value
	for field in [
		"run_id",
		"capture_stream_id",
		"observer_profile_id",
		"observer_adapter_id",
		"sample_phase",
	]:
		var field_value: Variant = identity.get(field)
		if not (field_value is String or field_value is StringName) \
				or String(field_value).is_empty():
			return {}
	if typeof(identity.get("physics_step_id")) != TYPE_INT \
			or int(identity["physics_step_id"]) < 0 \
			or typeof(identity.get("capture_epoch")) != TYPE_INT \
			or int(identity["capture_epoch"]) < 0:
		return {}
	return identity.duplicate(true)


func _invalid_input(reason: String, identity: Dictionary) -> Dictionary:
	return {"valid": false, "reason": reason, "identity": identity}
