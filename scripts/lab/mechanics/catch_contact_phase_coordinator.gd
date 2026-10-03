class_name LabCatchContactPhaseCoordinator
extends RefCounted
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## BR10 observed SEARCH -> TOUCH -> LOAD -> BEARING state machine.
##
## Target arrival is retained as a diagnostic only. Contact and load phases can
## advance solely from explicit ground-qualified contact and an available local
## normal-load observation. The load channel is a bounded unary touchdown
## witness, not a generalized per-foot support allocation.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const CONFIGURATION_SCHEMA := "catch_contact_phase_configuration_v1"
const OBSERVATION_SCHEMA := "catch_contact_phase_observation_v1"
const RESULT_SCHEMA := "catch_contact_phase_result_v1"
const VALID_PHASES: Array[String] = ["SEARCH", "TOUCH", "LOAD", "BEARING", "LOST"]
const CONFIGURATION_FIELDS: Array[String] = [
	"schema_version",
	"support_id",
	"contact_confirm_ticks",
	"load_confirm_ticks",
	"bearing_confirm_ticks",
	"load_enter_n",
	"bearing_enter_n",
	"maximum_separating_speed_m_s",
]
const OBSERVATION_FIELDS: Array[String] = [
	"schema_version",
	"tick",
	"target_arrived",
	"ground_contact_observed",
	"ground_qualified",
	"normal_load_available",
	"normal_load_n",
	"relative_separation_speed_available",
	"relative_separation_speed_m_s",
]

var _configuration: Dictionary = {}
var _phase := "SEARCH"
var _last_tick := -1
var _contact_ticks := 0
var _load_ticks := 0
var _bearing_ticks := 0
var _transition_count := 0


func configure(configuration: Dictionary) -> Dictionary:
	if not _field_set_matches(configuration, CONFIGURATION_FIELDS):
		return _failure("CATCH_PHASE_CONFIGURATION_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != CONFIGURATION_SCHEMA:
		return _failure("CATCH_PHASE_CONFIGURATION_SCHEMA_UNSUPPORTED")
	if String(configuration.get("support_id", "")).is_empty():
		return _failure("CATCH_PHASE_SUPPORT_ID_INVALID")
	for field in ["contact_confirm_ticks", "load_confirm_ticks", "bearing_confirm_ticks"]:
		if not configuration.get(field) is int or int(configuration[field]) <= 0:
			return _failure("CATCH_PHASE_CONFIRMATION_TICKS_INVALID:%s" % field)
	for field in ["load_enter_n", "bearing_enter_n", "maximum_separating_speed_m_s"]:
		if not _finite_number(configuration.get(field)) or float(configuration[field]) < 0.0:
			return _failure("CATCH_PHASE_THRESHOLD_INVALID:%s" % field)
	if (
		float(configuration["load_enter_n"]) <= 0.0
		or float(configuration["bearing_enter_n"]) < float(configuration["load_enter_n"])
	):
		return _failure("CATCH_PHASE_LOAD_ORDER_INVALID")
	_configuration = configuration.duplicate(true)
	_configuration["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	_phase = "SEARCH"
	_last_tick = -1
	_contact_ticks = 0
	_load_ticks = 0
	_bearing_ticks = 0
	_transition_count = 0
	return {"ok": true, "configuration": FrozenValueScript.snapshot(_configuration)}


func update(observation: Dictionary) -> Dictionary:
	if _configuration.is_empty():
		return _failure("CATCH_PHASE_NOT_CONFIGURED")
	if not _field_set_matches(observation, OBSERVATION_FIELDS):
		return _failure("CATCH_PHASE_OBSERVATION_FIELD_SET_MISMATCH")
	if String(observation.get("schema_version", "")) != OBSERVATION_SCHEMA:
		return _failure("CATCH_PHASE_OBSERVATION_SCHEMA_UNSUPPORTED")
	if not observation.get("tick") is int or int(observation["tick"]) != _last_tick + 1:
		return _failure("CATCH_PHASE_TICK_NOT_MONOTONIC")
	for field in [
		"target_arrived",
		"ground_contact_observed",
		"ground_qualified",
		"normal_load_available",
		"relative_separation_speed_available",
	]:
		if typeof(observation.get(field)) != TYPE_BOOL:
			return _failure("CATCH_PHASE_OBSERVATION_BOOL_INVALID:%s" % field)
	if not _available_number_valid(observation, "normal_load_available", "normal_load_n"):
		return _failure("CATCH_PHASE_NORMAL_LOAD_INVALID")
	if not _available_number_valid(
		observation, "relative_separation_speed_available", "relative_separation_speed_m_s"
	):
		return _failure("CATCH_PHASE_SEPARATION_SPEED_INVALID")
	_last_tick = int(observation["tick"])
	var previous := _phase
	var contact := (
		bool(observation["ground_contact_observed"]) and bool(observation["ground_qualified"])
	)
	var load_ready := (
		contact
		and bool(observation["normal_load_available"])
		and float(observation["normal_load_n"]) >= float(_configuration["load_enter_n"])
	)
	var bearing_ready := (
		load_ready
		and float(observation["normal_load_n"]) >= float(_configuration["bearing_enter_n"])
		and bool(observation["relative_separation_speed_available"])
		and (
			float(observation["relative_separation_speed_m_s"])
			<= float(_configuration["maximum_separating_speed_m_s"])
		)
	)
	_contact_ticks = _contact_ticks + 1 if contact else 0
	_load_ticks = _load_ticks + 1 if load_ready else 0
	_bearing_ticks = _bearing_ticks + 1 if bearing_ready else 0

	if not contact:
		_phase = "LOST" if previous in ["TOUCH", "LOAD", "BEARING"] else "SEARCH"
	elif previous in ["SEARCH", "LOST"]:
		if _contact_ticks >= int(_configuration["contact_confirm_ticks"]):
			_phase = "TOUCH"
	elif previous == "TOUCH":
		if _load_ticks >= int(_configuration["load_confirm_ticks"]):
			_phase = "LOAD"
	elif previous == "LOAD":
		if _bearing_ticks >= int(_configuration["bearing_confirm_ticks"]):
			_phase = "BEARING"
	elif previous == "BEARING" and not bearing_ready:
		_phase = "LOAD"
	if _phase != previous:
		_transition_count += 1
	var result := {
		"schema_version": RESULT_SCHEMA,
		"configuration_sha256": _configuration["configuration_sha256"],
		"support_id": _configuration["support_id"],
		"tick": _last_tick,
		"previous_phase": previous,
		"phase": _phase,
		"transitioned": _phase != previous,
		"transition_count": _transition_count,
		"target_arrived": observation["target_arrived"],
		"target_arrival_used_for_transition": false,
		"ground_contact_observed": contact,
		"normal_load_available": observation["normal_load_available"],
		"normal_load_n": observation["normal_load_n"],
		"contact_ticks": _contact_ticks,
		"load_ticks": _load_ticks,
		"bearing_ticks": _bearing_ticks,
		"bearing_established": _phase == "BEARING",
		"local_load_is_generalized_per_foot_allocation": false,
	}
	result["result_sha256"] = CanonicalJsonScript.sha256(result)
	return {"ok": true, "result": FrozenValueScript.snapshot(result)}


func phase() -> String:
	return _phase


static func _available_number_valid(
	observation: Dictionary, available_field: String, value_field: String
) -> bool:
	if bool(observation[available_field]):
		return _finite_number(observation.get(value_field))
	return observation.get(value_field) == null


static func _field_set_matches(value: Dictionary, fields: Array[String]) -> bool:
	var actual: Array = value.keys()
	actual.sort()
	var expected: Array = fields.duplicate()
	expected.sort()
	return actual == expected


static func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
