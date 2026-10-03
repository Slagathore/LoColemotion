class_name LabCaptureClock
extends RefCounted

## Runner-owned identity clock for direct-state captures.
##
## A body callback is not allowed to invent its own global tick. The runner opens
## exactly one epoch immediately before awaiting a physics frame, and every body
## callback in that step reads the same immutable tag.

const VALID_SAMPLE_PHASES := {
	&"integrate_callback": true,
	&"post_step": true,
}

var _physics_step_id := -1
var _capture_epoch := -1
var _physics_time_s := 0.0
var _sample_phase: StringName = &"integrate_callback"
var _open := false


func open_epoch(
		physics_step_id: int,
		physics_time_s: float,
		sample_phase: StringName = &"integrate_callback") -> Dictionary:
	assert(physics_step_id >= 0, "physics_step_id must be non-negative")
	assert(is_finite(physics_time_s) and physics_time_s >= 0.0,
			"physics_time_s must be finite and non-negative")
	assert(VALID_SAMPLE_PHASES.has(sample_phase), "unregistered sample phase")
	assert(not _open, "capture epoch is already open")
	assert(_physics_step_id < 0 or physics_step_id == _physics_step_id + 1,
			"physics_step_id must advance by exactly one")

	_physics_step_id = physics_step_id
	_capture_epoch += 1
	_physics_time_s = physics_time_s
	_sample_phase = sample_phase
	_open = true
	return current_tag()


func close_epoch() -> void:
	assert(_open, "no capture epoch is open")
	_open = false


func current_tag() -> Dictionary:
	if not _open:
		return {}
	return {
		"physics_step_id": _physics_step_id,
		"capture_epoch": _capture_epoch,
		"physics_time_s": _physics_time_s,
		"sample_phase": String(_sample_phase),
	}


func is_open() -> bool:
	return _open


func physics_step_id() -> int:
	return _physics_step_id


func capture_epoch() -> int:
	return _capture_epoch
