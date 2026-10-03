class_name LabBraceSupervisor
extends RefCounted

## BR8 hysteretic STAND/PRECARIOUS/BRACE observer supervisor.
##
## Escalation is immediate. De-escalation is one state at a time and requires
## consecutive safe-release evidence. The supervisor reports what a later brace
## controller would need to do, but it performs no actuation itself.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const STATES: Array[String] = ["STAND", "PRECARIOUS", "BRACE"]

var _state := "STAND"
var _release_dwell_ticks := 3
var _release_count := 0
var _last_tick := -1
var _transition_sequence := 0


func _init(release_dwell_ticks: int = 3) -> void:
	if release_dwell_ticks > 0:
		_release_dwell_ticks = release_dwell_ticks


func update(tick: int, evidence: Dictionary) -> Dictionary:
	if tick < 0 or tick <= _last_tick:
		return {"ok": false, "failure_code": "BRACE_SUPERVISOR_TICK_INVALID"}
	if not _valid_evidence(tick, evidence):
		return {"ok": false, "failure_code": "BRACE_SUPERVISOR_EVIDENCE_INVALID"}
	_last_tick = tick
	var requested := String(evidence["recommended_state"])
	var previous := _state
	var transition: Dictionary = {}
	if _severity(requested) > _severity(_state):
		_state = requested
		_release_count = 0
	elif _severity(requested) < _severity(_state):
		if bool(evidence["safe_release_candidate"]):
			_release_count += 1
		else:
			_release_count = 0
		if _release_count >= _release_dwell_ticks:
			_state = STATES[_severity(_state) - 1]
			_release_count = 0
	else:
		_release_count = 0
	if _state != previous:
		_transition_sequence += 1
		var transition_payload := {
			"schema_version": "brace_transition_v1",
			"sequence": _transition_sequence,
			"tick": tick,
			"from_state": previous,
			"to_state": _state,
			"reason": String(evidence["dominant_reason"]),
			"static_margin_m": float(evidence["static_margin_m"]),
			"capture_margin_m": float(evidence["capture_margin_m"]),
			"earliest_deadline_available": bool(evidence["earliest_deadline_available"]),
			"earliest_deadline_s": float(evidence["earliest_deadline_s"]),
			"reaction_viable": bool(evidence["reaction_viable"]),
			"evidence_sha256": CanonicalJsonScript.sha256(evidence),
		}
		transition = FrozenValueScript.snapshot(transition_payload)
	var response := "CONTINUE_STANCE_OBSERVATION"
	if _state == "PRECARIOUS":
		response = "INCREASE_OBSERVATION_RATE_NO_ACTUATION"
	elif _state == "BRACE":
		response = (
			"DECLARE_REACTION_TOO_LATE_STOP"
			if String(evidence["dominant_reason"]) == "REACTION_TOO_LATE"
			else "DECLARE_BRACE_REQUIRED_NO_ACTUATION"
		)
	return {
		"ok": true,
		"state": _state,
		"response": response,
		"release_dwell_progress": _release_count,
		"release_dwell_required": _release_dwell_ticks,
		"transition": transition,
		"automatic_force_application": false,
		"automatic_step_command": false,
		"automatic_creature_guidance": false,
	}


static func _valid_evidence(tick: int, evidence: Dictionary) -> bool:
	var required := [
		"schema_version",
		"tick",
		"recommended_state",
		"dominant_reason",
		"static_margin_m",
		"capture_margin_m",
		"earliest_deadline_available",
		"earliest_deadline_s",
		"reaction_viable",
		"safe_release_candidate",
	]
	for field in required:
		if not evidence.has(field):
			return false
	if (
		String(evidence["schema_version"]) != "brace_detection_evidence_v1"
		or int(evidence["tick"]) != tick
		or not STATES.has(String(evidence["recommended_state"]))
		or typeof(evidence["dominant_reason"]) != TYPE_STRING
		or typeof(evidence["earliest_deadline_available"]) != TYPE_BOOL
		or typeof(evidence["reaction_viable"]) != TYPE_BOOL
		or typeof(evidence["safe_release_candidate"]) != TYPE_BOOL
	):
		return false
	for field in [
		"static_margin_m",
		"capture_margin_m",
		"earliest_deadline_s",
	]:
		if (
			typeof(evidence[field]) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(evidence[field]))
		):
			return false
	return true


static func _severity(state: String) -> int:
	return STATES.find(state)
