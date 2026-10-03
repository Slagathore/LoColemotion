class_name SensorFrameBuilder
extends RefCounted

## Builds one temporally coherent, JSON-ready L0 sensor frame.
##
## Samples from adjacent physics callbacks must never be blended. A frame is
## invalid if any required body is missing or carries a different step, epoch,
## or sample phase.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const WholeBodyStateScript := preload(
	"res://scripts/lab/mechanics/whole_body_state.gd")

var frame_id := -1
var physics_step_id := -1
var capture_epoch := -1
var physics_time_s := 0.0
var sample_phase: StringName = &""
var experiment_phase: StringName = &""
var release_frame_id := -1
var bodies_by_id: Dictionary = {}
var contacts: Array = []
var availability: Dictionary = {}
var finite := true

var _required_body_ids: Array[StringName] = []
var _sealed := false
var _invalid_reasons: Array[String] = []


func begin(
		next_frame_id: int,
		next_physics_time_s: float,
		next_sample_phase: StringName,
		next_experiment_phase: StringName,
		next_release_frame_id := 0,
		required_body_ids: Array[StringName] = []) -> void:
	assert(not _sealed, "a sealed SensorFrameBuilder cannot be reused")
	assert(next_frame_id >= 0)
	assert(is_finite(next_physics_time_s) and next_physics_time_s >= 0.0)
	frame_id = next_frame_id
	physics_time_s = next_physics_time_s
	sample_phase = next_sample_phase
	experiment_phase = next_experiment_phase
	release_frame_id = next_release_frame_id
	_required_body_ids = required_body_ids.duplicate()


func add_body_sample(sample: Dictionary) -> bool:
	if _sealed or sample.is_empty():
		return false
	var stable_id := String(sample.get("body_id", ""))
	if stable_id.is_empty() or bodies_by_id.has(stable_id):
		_invalidate("missing or duplicate body_id: %s" % stable_id)
		return false
	var sample_step := int(sample.get("physics_step_id", -1))
	var sample_epoch := int(sample.get("capture_epoch", -1))
	var phase := StringName(sample.get("sample_phase", ""))
	if bodies_by_id.is_empty():
		physics_step_id = sample_step
		capture_epoch = sample_epoch
	elif sample_step != physics_step_id or sample_epoch != capture_epoch:
		_invalidate("body samples span multiple physics steps or epochs")
	if phase != sample_phase:
		_invalidate("body sample phase does not match frame phase")
	if not bool(sample.get("finite", false)):
		_invalidate("body sample is non-finite: %s" % stable_id)
	bodies_by_id[stable_id] = sample.duplicate(true)
	return true


func add_contacts(body_contacts: Array) -> bool:
	if _sealed:
		return false
	for contact in body_contacts:
		if not contact is Dictionary:
			_invalidate("contact is not a dictionary")
			return false
		var value: Dictionary = contact
		if (
				int(value.get("physics_step_id", -1)) != physics_step_id
				or int(value.get("capture_epoch", -1)) != capture_epoch
				or StringName(value.get("sample_phase", "")) != sample_phase):
			_invalidate("contact does not match the frame epoch")
		if not bool(value.get("finite", false)):
			_invalidate("contact contains a non-finite value")
		contacts.append(value.duplicate(true))
	return true


func seal() -> Dictionary:
	assert(not _sealed, "SensorFrameBuilder.seal() may only be called once")
	_sealed = true
	for required_id in _required_body_ids:
		if not bodies_by_id.has(String(required_id)):
			_invalidate("required body was not captured: %s" % String(required_id))
	if bodies_by_id.is_empty():
		_invalidate("frame contains no body samples")

	var sorted_body_ids := bodies_by_id.keys()
	sorted_body_ids.sort()
	var sorted_bodies: Dictionary = {}
	for stable_id in sorted_body_ids:
		sorted_bodies[stable_id] = bodies_by_id[stable_id]
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("contact_key", "")) < String(
			b.get("contact_key", "")))

	var whole_body: Dictionary = WholeBodyStateScript.from_frame({
		"frame_id": frame_id,
		"physics_step_id": physics_step_id,
		"capture_epoch": capture_epoch,
		"bodies": sorted_bodies,
	})
	if whole_body.is_empty():
		_invalidate("whole-body aggregation unavailable")

	var field_availability: Dictionary = {}
	for stable_id in sorted_body_ids:
		field_availability["body:%s" % stable_id] = {
			"status": "measured",
			"reason": null,
			"source": "rigid_body_integrate_forces_v1",
		}
	field_availability["contacts"] = {
		"status": "measured",
		"reason": null,
		"source": "rigid_body_integrate_forces_v1",
	}
	field_availability["whole_body"] = {
		"status": "derived" if not whole_body.is_empty() else "invalid",
		"reason": null if not whole_body.is_empty() else "AGGREGATION_FAILED",
		"source": "whole_body_state_v1",
	}
	field_availability["frame"] = {
		"status": "measured" if finite else "invalid",
		"reason": (
			null
			if finite
			else "; ".join(_invalid_reasons)),
		"source": "sensor_frame_builder_v1",
	}
	availability = {
		"required_body_ids": _required_body_ids.map(
			func(value: StringName) -> String: return String(value)),
		"captured_body_count": sorted_bodies.size(),
		"contact_count": contacts.size(),
		"invalid_reasons": _invalid_reasons.duplicate(),
		"fields": field_availability,
	}
	return FrozenValueScript.snapshot({
		"schema_version": "frame_v1",
		"frame_id": frame_id,
		"physics_step_id": physics_step_id,
		"capture_epoch": capture_epoch,
		"physics_time_s": physics_time_s,
		"sample_phase": String(sample_phase),
		"experiment_phase": String(experiment_phase),
		"release_frame_id": release_frame_id,
		"bodies": sorted_bodies,
		"contacts": contacts,
		"whole_body": whole_body,
		"availability": availability,
		"finite": finite,
	})


func invalid_reasons() -> Array[String]:
	return _invalid_reasons.duplicate()


func _invalidate(reason: String) -> void:
	finite = false
	_invalid_reasons.append(reason)
