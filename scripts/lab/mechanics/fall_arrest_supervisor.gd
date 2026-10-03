class_name LabFallArrestSupervisor
extends RefCounted

## Observation-authoritative BR11 fall-arrest supervisor.
##
## The supervisor reports phase authority only. It applies no force, torque,
## root rescue, pose teleport, pin, creature edit, or automatic guidance.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const CONFIGURATION_SCHEMA := "fall_arrest_supervisor_configuration_v1"
const INPUT_SCHEMA := "fall_arrest_supervisor_input_v1"
const CONFIGURATION_FIELDS: Array[String] = [
	"schema_version",
	"supervisor_id",
	"fallen_confirm_ticks",
	"automatic_creature_guidance_allowed",
]
const INPUT_FIELDS: Array[String] = [
	"schema_version",
	"tick",
	"upright_recovery_feasible",
	"impact_imminent",
	"protective_capacity_available",
	"stable_fallen_observed",
]

var _configuration: Dictionary = {}
var _phase := "MONITOR"
var _last_tick := -1
var _fallen_dwell := 0


func configure(configuration: Dictionary) -> Dictionary:
	var keys := _sorted_keys(configuration)
	var expected: Array = CONFIGURATION_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		return _failure("FALL_ARREST_SUPERVISOR_CONFIGURATION_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != CONFIGURATION_SCHEMA:
		return _failure("FALL_ARREST_SUPERVISOR_CONFIGURATION_SCHEMA_UNSUPPORTED")
	if not _stable_id(String(configuration.get("supervisor_id", ""))):
		return _failure("FALL_ARREST_SUPERVISOR_ID_INVALID")
	if (
		typeof(configuration.get("fallen_confirm_ticks")) != TYPE_INT
		or int(configuration["fallen_confirm_ticks"]) < 1
	):
		return _failure("FALL_ARREST_FALLEN_CONFIRM_TICKS_INVALID")
	if (
		not configuration.get("automatic_creature_guidance_allowed") is bool
		or bool(configuration["automatic_creature_guidance_allowed"])
	):
		return _failure("FALL_ARREST_SUPERVISOR_GUIDANCE_FORBIDDEN")
	_configuration = configuration.duplicate(true)
	_configuration["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	_phase = "MONITOR"
	_last_tick = -1
	_fallen_dwell = 0
	return {
		"ok": true,
		"configuration": FrozenValueScript.snapshot(_configuration),
	}


func observe(input: Dictionary) -> Dictionary:
	if _configuration.is_empty():
		return _failure("FALL_ARREST_SUPERVISOR_NOT_CONFIGURED")
	var keys := _sorted_keys(input)
	var expected: Array = INPUT_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		return _failure("FALL_ARREST_SUPERVISOR_INPUT_FIELD_SET_MISMATCH")
	if String(input.get("schema_version", "")) != INPUT_SCHEMA:
		return _failure("FALL_ARREST_SUPERVISOR_INPUT_SCHEMA_UNSUPPORTED")
	if typeof(input.get("tick")) != TYPE_INT or int(input["tick"]) <= _last_tick:
		return _failure("FALL_ARREST_SUPERVISOR_TICK_NONMONOTONIC")
	for field in [
		"upright_recovery_feasible",
		"impact_imminent",
		"protective_capacity_available",
		"stable_fallen_observed",
	]:
		if not input.get(field) is bool:
			return _failure("FALL_ARREST_SUPERVISOR_BOOLEAN_INVALID:%s" % field)
	var before := _phase
	var reason := "NO_TRANSITION"
	if _phase == "MONITOR":
		if (
			not bool(input["upright_recovery_feasible"])
			and bool(input["impact_imminent"])
			and bool(input["protective_capacity_available"])
		):
			_phase = "FALL_ARREST"
			reason = "RECOVERY_INFEASIBLE_IMPACT_IMMINENT"
		elif (
			not bool(input["upright_recovery_feasible"])
			and bool(input["impact_imminent"])
			and not bool(input["protective_capacity_available"])
		):
			reason = "INSUFFICIENT_PROTECTIVE_CAPACITY"
	if bool(input["stable_fallen_observed"]):
		_fallen_dwell += 1
	else:
		_fallen_dwell = 0
	if _phase != "FALLEN" and _fallen_dwell >= int(_configuration["fallen_confirm_ticks"]):
		_phase = "FALLEN"
		reason = "STABLE_FALLEN_DWELL_COMPLETE"
	_last_tick = int(input["tick"])
	return (
		FrozenValueScript
		. snapshot(
			{
				"ok": true,
				"tick": _last_tick,
				"before_phase": before,
				"phase": _phase,
				"reason": reason,
				"fallen_dwell_ticks": _fallen_dwell,
				"configuration_sha256": _configuration["configuration_sha256"],
				"force_authority": false,
				"torque_authority": false,
				"automatic_creature_guidance_allowed": false,
			}
		)
	)


static func _sorted_keys(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys


static func _stable_id(value: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^[A-Za-z][A-Za-z0-9._:-]{0,159}$")
	return expression.search(value) != null


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
