class_name LabRecoveryPhaseSupervisor
extends RefCounted
# gdlint: disable=max-returns

## Observation-authoritative BR13 recovery phase supervisor.
##
## The supervisor grants phase authority only. It has no force, torque,
## contact, pose, root-rescue, repair, or automatic-guidance authority.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const PHASES: Array[String] = [
	"CONFIRM_PRONE",
	"ESTABLISH_DISTAL_CONTACT",
	"RAISE_BODY",
	"STANCE_HANDOFF",
	"STANCE_DWELL",
	"COMPLETE",
	"FAILED",
]
const TIMED_PHASES: Array[String] = [
	"CONFIRM_PRONE",
	"ESTABLISH_DISTAL_CONTACT",
	"RAISE_BODY",
	"STANCE_HANDOFF",
	"STANCE_DWELL",
]
const CONFIGURATION_FIELDS: Array[String] = [
	"schema_version",
	"supervisor_id",
	"prone_confirm_ticks",
	"stance_dwell_ticks",
	"rise_height_ratio_min",
	"phase_timeout_ticks",
	"automatic_creature_guidance_allowed",
]
const INPUT_FIELDS: Array[String] = [
	"schema_version",
	"tick",
	"pose_state",
	"height_ratio",
	"front_pair_bearing",
	"rear_pair_bearing",
	"energy_gate_passed",
	"actuator_reserve_passed",
	"forbidden_contact_observed",
	"recovery_controller_active",
	"stance_controller_active",
]

var _configuration: Dictionary = {}
var _phase := "CONFIRM_PRONE"
var _phase_enter_tick := 0
var _last_tick := -1
var _prone_dwell := 0
var _stance_dwell := 0
var _failure_code := ""


func configure(configuration: Dictionary) -> Dictionary:
	if not _exact_fields(configuration, CONFIGURATION_FIELDS):
		return _failure("RECOVERY_SUPERVISOR_CONFIGURATION_FIELDS_INVALID")
	if String(configuration.get("schema_version", "")) != "recovery_phase_supervisor_v1":
		return _failure("RECOVERY_SUPERVISOR_CONFIGURATION_SCHEMA_INVALID")
	if not _stable_id(String(configuration.get("supervisor_id", ""))):
		return _failure("RECOVERY_SUPERVISOR_ID_INVALID")
	for field in ["prone_confirm_ticks", "stance_dwell_ticks"]:
		if typeof(configuration.get(field)) != TYPE_INT or int(configuration[field]) < 1:
			return _failure("RECOVERY_SUPERVISOR_DWELL_INVALID:%s" % field)
	if (
		not _finite_number(configuration.get("rise_height_ratio_min"))
		or float(configuration["rise_height_ratio_min"]) <= 0.6
		or float(configuration["rise_height_ratio_min"]) > 1.0
	):
		return _failure("RECOVERY_SUPERVISOR_RISE_HEIGHT_INVALID")
	var timeouts := _timeouts(configuration.get("phase_timeout_ticks"))
	if not bool(timeouts.get("ok", false)):
		return timeouts
	if (
		typeof(configuration.get("automatic_creature_guidance_allowed")) != TYPE_BOOL
		or bool(configuration["automatic_creature_guidance_allowed"])
	):
		return _failure("RECOVERY_SUPERVISOR_GUIDANCE_FORBIDDEN")
	_configuration = configuration.duplicate(true)
	_configuration["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	_phase = "CONFIRM_PRONE"
	_phase_enter_tick = 0
	_last_tick = -1
	_prone_dwell = 0
	_stance_dwell = 0
	_failure_code = ""
	return {"ok": true, "configuration": FrozenValueScript.snapshot(_configuration)}


func observe(input: Dictionary) -> Dictionary:
	if _configuration.is_empty():
		return _failure("RECOVERY_SUPERVISOR_NOT_CONFIGURED")
	if not _exact_fields(input, INPUT_FIELDS):
		return _failure("RECOVERY_SUPERVISOR_INPUT_FIELDS_INVALID")
	if (
		String(input.get("schema_version", "")) != "recovery_phase_observation_v1"
		or typeof(input.get("tick")) != TYPE_INT
		or int(input["tick"]) <= _last_tick
	):
		return _failure("RECOVERY_SUPERVISOR_TICK_INVALID")
	if String(input.get("pose_state", "")) not in ["PRONE", "TRANSITION", "STANCE", "UNKNOWN"]:
		return _failure("RECOVERY_SUPERVISOR_POSE_INVALID")
	if not _finite_number(input.get("height_ratio")) or float(input["height_ratio"]) < 0.0:
		return _failure("RECOVERY_SUPERVISOR_HEIGHT_INVALID")
	for field in [
		"front_pair_bearing",
		"rear_pair_bearing",
		"energy_gate_passed",
		"actuator_reserve_passed",
		"forbidden_contact_observed",
		"recovery_controller_active",
		"stance_controller_active",
	]:
		if typeof(input.get(field)) != TYPE_BOOL:
			return _failure("RECOVERY_SUPERVISOR_BOOLEAN_INVALID:%s" % field)
	var tick := int(input["tick"])
	var before := _phase
	var reason := "NO_TRANSITION"
	if _phase not in ["COMPLETE", "FAILED"]:
		if bool(input["forbidden_contact_observed"]):
			_fail("FORBIDDEN_CONTACT_OBSERVED", tick)
			reason = _failure_code
		elif not bool(input["energy_gate_passed"]):
			_fail("RECOVERY_ENERGY_GATE_REVOKED", tick)
			reason = _failure_code
		elif not bool(input["actuator_reserve_passed"]):
			_fail("RECOVERY_ACTUATOR_RESERVE_REVOKED", tick)
			reason = _failure_code
		elif _timed_out(tick):
			_fail("RECOVERY_PHASE_TIMEOUT:%s" % _phase, tick)
			reason = _failure_code
		else:
			reason = _advance(input, tick)
	_last_tick = tick
	return (
		FrozenValueScript
		. snapshot(
			{
				"ok": true,
				"tick": tick,
				"before_phase": before,
				"phase": _phase,
				"reason": reason,
				"phase_enter_tick": _phase_enter_tick,
				"prone_dwell_ticks": _prone_dwell,
				"stance_dwell_ticks": _stance_dwell,
				"failure_code": _failure_code,
				"recovery_controller_may_be_active":
				_phase in ["ESTABLISH_DISTAL_CONTACT", "RAISE_BODY"],
				"stance_controller_may_be_active":
				_phase in ["STANCE_HANDOFF", "STANCE_DWELL", "COMPLETE"],
				"force_authority": false,
				"torque_authority": false,
				"contact_creation_authority": false,
				"automatic_creature_guidance_allowed": false,
				"configuration_sha256": _configuration["configuration_sha256"],
			}
		)
	)


func _advance(input: Dictionary, tick: int) -> String:
	match _phase:
		"CONFIRM_PRONE":
			if (
				String(input["pose_state"]) == "PRONE"
				and not bool(input["recovery_controller_active"])
				and not bool(input["stance_controller_active"])
			):
				_prone_dwell += 1
			else:
				_prone_dwell = 0
			if _prone_dwell >= int(_configuration["prone_confirm_ticks"]):
				_transition("ESTABLISH_DISTAL_CONTACT", tick)
				return "PRONE_DWELL_COMPLETE"
		"ESTABLISH_DISTAL_CONTACT":
			if bool(input["front_pair_bearing"]) and bool(input["rear_pair_bearing"]):
				_transition("RAISE_BODY", tick)
				return "BOTH_DISTAL_PAIRS_BEARING"
		"RAISE_BODY":
			if (
				bool(input["front_pair_bearing"])
				and bool(input["rear_pair_bearing"])
				and (float(input["height_ratio"]) >= float(_configuration["rise_height_ratio_min"]))
				and String(input["pose_state"]) in ["TRANSITION", "STANCE"]
			):
				_transition("STANCE_HANDOFF", tick)
				return "OBSERVED_BODY_RISE_COMPLETE"
		"STANCE_HANDOFF":
			if (
				String(input["pose_state"]) == "STANCE"
				and not bool(input["recovery_controller_active"])
				and bool(input["stance_controller_active"])
			):
				_transition("STANCE_DWELL", tick)
				_stance_dwell = 1
				return "STANCE_CONTROLLER_OBSERVED"
		"STANCE_DWELL":
			if (
				String(input["pose_state"]) == "STANCE"
				and bool(input["front_pair_bearing"])
				and bool(input["rear_pair_bearing"])
				and not bool(input["recovery_controller_active"])
				and bool(input["stance_controller_active"])
			):
				_stance_dwell += 1
			else:
				_stance_dwell = 0
			if _stance_dwell >= int(_configuration["stance_dwell_ticks"]):
				_transition("COMPLETE", tick)
				return "STANCE_DWELL_COMPLETE"
	return "NO_TRANSITION"


func _timed_out(tick: int) -> bool:
	if _phase not in TIMED_PHASES:
		return false
	var timeouts: Dictionary = _configuration["phase_timeout_ticks"]
	return tick - _phase_enter_tick > int(timeouts[_phase])


func _transition(next_phase: String, tick: int) -> void:
	_phase = next_phase
	_phase_enter_tick = tick


func _fail(code: String, tick: int) -> void:
	_failure_code = code
	_transition("FAILED", tick)


static func _timeouts(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("RECOVERY_SUPERVISOR_TIMEOUTS_INVALID")
	var timeouts: Dictionary = value
	if timeouts.size() != TIMED_PHASES.size():
		return _failure("RECOVERY_SUPERVISOR_TIMEOUTS_INVALID")
	for phase in TIMED_PHASES:
		if (
			not timeouts.has(phase)
			or typeof(timeouts[phase]) != TYPE_INT
			or int(timeouts[phase]) < 1
		):
			return _failure("RECOVERY_SUPERVISOR_TIMEOUTS_INVALID")
	return {"ok": true}


static func _stable_id(value: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^[A-Za-z][A-Za-z0-9._:-]{0,159}$")
	return expression.search(value) != null


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
