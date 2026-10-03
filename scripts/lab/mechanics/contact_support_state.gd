class_name LabContactSupportState
extends RefCounted

## BR3A pure per-support contact phase machine.
##
## The state machine consumes a versioned LabGroundQualifier result plus
## explicit load and normal-separation channels. It never reads foot height,
## target position, target arrival, desired force, or controller pose. Those
## may be useful commands or diagnostics, but they are not observed support.
##
## State order:
##
##     SEARCH -> TOUCH -> LOAD -> BEARING
##     BEARING --explicit release--> UNLOAD -> SEARCH
##     BEARING --unexpected evidence loss--> LOST -> SEARCH/TOUCH
##
## Exactly one transition is permitted per observation. Consecutive samples
## must advance physics_step_id and capture_epoch by exactly one and retain the
## configured sample_phase. A gap emits a non-finite LOST result that requires
## explicit reinitialization; it never guesses across missing evidence.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const GroundQualifierScript := preload(
	"res://scripts/lab/mechanics/ground_qualifier.gd")

const CONFIG_SCHEMA_VERSION := "contact_support_state_config_v1"
const RESULT_SCHEMA_VERSION := "contact_support_state_v1"

const SEARCH := "SEARCH"
const TOUCH := "TOUCH"
const LOAD := "LOAD"
const BEARING := "BEARING"
const UNLOAD := "UNLOAD"
const LOST := "LOST"
const VALID_STATES := [SEARCH, TOUCH, LOAD, BEARING, UNLOAD, LOST]
const VALID_SAMPLE_PHASES := ["integrate_callback", "post_step"]


static func build_config(configuration: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	var support_id := _stable_name(
		configuration.get("support_id"), "/support_id", errors)
	var sample_phase := _stable_name(
		configuration.get("sample_phase"), "/sample_phase", errors)
	var ground_qualifier_config_digest := _sha256_digest(
		configuration.get("ground_qualifier_config_digest_sha256"),
		"/ground_qualifier_config_digest_sha256",
		errors)
	var contact_confirm_ticks := _positive_integer(
		configuration.get("contact_confirm_ticks"),
		"/contact_confirm_ticks",
		errors)
	var bearing_confirm_ticks := _positive_integer(
		configuration.get("bearing_confirm_ticks"),
		"/bearing_confirm_ticks",
		errors)

	var bearing_enter_load_n := _finite_float(
		configuration.get("bearing_enter_load_n"),
		"/bearing_enter_load_n",
		errors)
	var bearing_exit_load_n := _finite_float(
		configuration.get("bearing_exit_load_n"),
		"/bearing_exit_load_n",
		errors)
	var unloaded_load_n := _finite_float(
		configuration.get("unloaded_load_n"),
		"/unloaded_load_n",
		errors)
	var maximum_separating_speed_mps := _finite_float(
		configuration.get("maximum_separating_speed_mps"),
		"/maximum_separating_speed_mps",
		errors)

	if bearing_enter_load_n <= 0.0:
		_add_error(
			errors,
			"BEARING_ENTER_LOAD_INVALID",
			"/bearing_enter_load_n",
			"Bearing-entry load must be greater than zero")
	if bearing_exit_load_n < 0.0 \
			or bearing_exit_load_n >= bearing_enter_load_n:
		_add_error(
			errors,
			"LOAD_HYSTERESIS_INVALID",
			"/bearing_exit_load_n",
			"Exit load must be nonnegative and strictly below entry load")
	if unloaded_load_n < 0.0 or unloaded_load_n > bearing_exit_load_n:
		_add_error(
			errors,
			"UNLOADED_LOAD_INVALID",
			"/unloaded_load_n",
			"Unloaded threshold must lie between zero and bearing-exit load")
	if maximum_separating_speed_mps < 0.0:
		_add_error(
			errors,
			"SEPARATING_SPEED_LIMIT_INVALID",
			"/maximum_separating_speed_mps",
			"Maximum separating speed must be nonnegative")

	if not errors.is_empty():
		return FrozenValueScript.snapshot({
			"ok": false,
			"errors": errors,
			"config": null,
		})

	var config := {
		"schema_version": CONFIG_SCHEMA_VERSION,
		"support_id": support_id,
		"sample_phase": sample_phase,
		"ground_qualifier_config_digest_sha256":
			ground_qualifier_config_digest,
		"contact_confirm_ticks": contact_confirm_ticks,
		"bearing_confirm_ticks": bearing_confirm_ticks,
		"bearing_enter_load_n": bearing_enter_load_n,
		"bearing_exit_load_n": bearing_exit_load_n,
		"unloaded_load_n": unloaded_load_n,
		"maximum_separating_speed_mps":
			maximum_separating_speed_mps,
		"load_hysteresis_band_n":
			bearing_enter_load_n - bearing_exit_load_n,
		"load_unavailable_policy": "never_numeric_zero",
		"temporal_gap_policy": "lost_and_explicit_reinitialize",
		"geometry_only_transition_forbidden": true,
		"accepted_normal_load_qualities": [
			"jolt_predicted_average_v1",
			"force_sensor_measured_v1",
		],
		"accepted_separation_velocity_qualities": [
			"canonical_patch_relative_velocity_v1",
		],
	}
	config["config_digest_sha256"] = CanonicalJsonScript.sha256(config)
	return FrozenValueScript.snapshot({
		"ok": true,
		"errors": [],
		"config": config,
	})


static func initialize(
		config: Dictionary,
		observation: Dictionary) -> Dictionary:
	var status := _observation_status(config, observation)
	if not bool(status["valid"]):
		return _invalid_result(
			config,
			{},
			status["identity"],
			status["reasons"],
			SEARCH)

	var qualifies := bool(status["qualifies_as_ground"])
	var state := TOUCH if qualifies else SEARCH
	var counters := _initial_counters()
	counters["qualified_contact_ticks"] = 1 if qualifies else 0
	if qualifies:
		counters["touchdown_count"] = 1
	var reason := (
		"INITIALIZED_WITH_QUALIFYING_CONTACT"
		if qualifies
		else "INITIALIZED_WITHOUT_QUALIFYING_CONTACT")
	return _seal_result(
		config,
		status,
		state,
		"UNINITIALIZED",
		false,
		reason,
		counters,
		false)


static func advance(
		config: Dictionary,
		previous: Dictionary,
		observation: Dictionary,
		release_requested: bool = false) -> Dictionary:
	var status := _observation_status(config, observation)
	var predecessor_reasons := _predecessor_reasons(
		config, previous, status["identity"])
	var invalid_reasons: Array[String] = []
	invalid_reasons.append_array(status["reasons"] as Array[String])
	invalid_reasons.append_array(predecessor_reasons)
	if not invalid_reasons.is_empty():
		return _invalid_result(
			config,
			previous,
			status["identity"],
			invalid_reasons,
			LOST)

	var previous_state := String(previous["support_state"])
	if bool(previous.get("ground_qualified", false)) \
			and bool(status["qualifies_as_ground"]) \
			and previous_state in [TOUCH, LOAD, BEARING, UNLOAD] \
			and String(previous.get("contact_patch_id", "")) \
				!= String(status["contact_patch_id"]):
		return _invalid_result(
			config,
			previous,
			status["identity"],
			["CONTACT_PATCH_ID_CHANGED_DURING_SUPPORT"],
			LOST)
	var next_state := previous_state
	var reason := "STATE_HELD"
	var qualifies := bool(status["qualifies_as_ground"])
	var load_available := bool(status["normal_load_available"])
	var separation_available := bool(
		status["relative_separation_velocity_available"])
	var normal_load_n := float(status["normal_load_n"])
	var separation_mps := float(status["relative_separation_velocity_mps"])
	var separating_too_fast := separation_available \
		and separation_mps > float(config["maximum_separating_speed_mps"])
	var entry_load_ready := qualifies \
		and separation_available and not separating_too_fast \
		and load_available \
		and normal_load_n >= float(config["bearing_enter_load_n"])

	var counters: Dictionary = (previous["counters"] as Dictionary).duplicate(true)
	counters["update_count"] = int(counters["update_count"]) + 1
	counters["qualified_contact_ticks"] = (
		int(counters["qualified_contact_ticks"]) + 1
		if qualifies
		else 0)
	counters["load_unavailable_ticks"] = (
		int(counters["load_unavailable_ticks"]) + 1
		if qualifies and not load_available
		else 0)
	counters["separation_unavailable_ticks"] = (
		int(counters["separation_unavailable_ticks"]) + 1
		if qualifies and not separation_available
		else 0)

	match previous_state:
		SEARCH:
			if qualifies:
				next_state = TOUCH
				reason = "QUALIFYING_CONTACT_APPEARED"
			else:
				reason = "SEARCH_NO_QUALIFYING_CONTACT"

		TOUCH:
			if not qualifies:
				next_state = SEARCH
				reason = "TOUCH_CONTACT_ENDED"
			elif not separation_available:
				reason = "TOUCH_SEPARATION_VELOCITY_UNAVAILABLE"
			elif separating_too_fast:
				reason = "TOUCH_CONTACT_SEPARATING_TOO_FAST"
			elif int(counters["qualified_contact_ticks"]) \
					>= int(config["contact_confirm_ticks"]):
				next_state = LOAD
				reason = "CONTACT_DWELL_CONFIRMED"
				counters["load_ready_ticks"] = 1 if entry_load_ready else 0
			else:
				reason = "TOUCH_WAITING_FOR_CONTACT_DWELL"

		LOAD:
			if not qualifies:
				next_state = SEARCH
				reason = "LOAD_CONTACT_ENDED"
				counters["load_ready_ticks"] = 0
			elif not separation_available:
				reason = "LOAD_SEPARATION_VELOCITY_UNAVAILABLE"
				counters["load_ready_ticks"] = 0
			elif separating_too_fast:
				next_state = TOUCH
				reason = "LOAD_CONTACT_SEPARATING_TOO_FAST"
				counters["load_ready_ticks"] = 0
			elif not load_available:
				reason = "LOAD_MEASUREMENT_UNAVAILABLE"
				counters["load_ready_ticks"] = 0
			elif entry_load_ready:
				counters["load_ready_ticks"] = \
					int(counters["load_ready_ticks"]) + 1
				if int(counters["load_ready_ticks"]) \
						>= int(config["bearing_confirm_ticks"]):
					next_state = BEARING
					reason = "BEARING_LOAD_DWELL_CONFIRMED"
				else:
					reason = "LOAD_WAITING_FOR_BEARING_DWELL"
			else:
				reason = "LOAD_BELOW_BEARING_ENTRY_THRESHOLD"
				counters["load_ready_ticks"] = 0

		BEARING:
			if release_requested:
				next_state = UNLOAD
				reason = "EXPLICIT_RELEASE_REQUESTED"
			elif not qualifies:
				next_state = LOST
				reason = "BEARING_CONTACT_LOST"
			elif not separation_available:
				next_state = LOST
				reason = "BEARING_SEPARATION_VELOCITY_UNAVAILABLE"
			elif separating_too_fast:
				next_state = LOST
				reason = "BEARING_CONTACT_SEPARATING_TOO_FAST"
			elif not load_available:
				next_state = LOST
				reason = "BEARING_LOAD_MEASUREMENT_UNAVAILABLE"
			elif normal_load_n < float(config["bearing_exit_load_n"]):
				next_state = LOST
				reason = "BEARING_LOAD_BELOW_EXIT_THRESHOLD"
			else:
				reason = "BEARING_EVIDENCE_HELD"

		UNLOAD:
			if not qualifies:
				next_state = SEARCH
				reason = "UNLOAD_CONTACT_RELEASED"
			elif not load_available:
				reason = "UNLOAD_LOAD_MEASUREMENT_UNAVAILABLE"
			elif normal_load_n <= float(config["unloaded_load_n"]):
				reason = "UNLOAD_FORCE_LOW_WAITING_FOR_CONTACT_RELEASE"
			else:
				reason = "UNLOAD_FORCE_ABOVE_RELEASE_THRESHOLD"

		LOST:
			if qualifies:
				next_state = TOUCH
				reason = "LOST_CONTACT_REACQUIRED"
			else:
				next_state = SEARCH
				reason = "LOST_EVENT_OBSERVED"

	var transitioned := next_state != previous_state
	if transitioned:
		counters["state_age_ticks"] = 1
		counters["transition_count"] = int(counters["transition_count"]) + 1
	else:
		counters["state_age_ticks"] = int(counters["state_age_ticks"]) + 1
	_update_transition_counters(
		counters, previous_state, next_state, transitioned)

	return _seal_result(
		config,
		status,
		next_state,
		previous_state,
		transitioned,
		reason,
		counters,
		release_requested)


static func _observation_status(
		config: Dictionary,
		observation: Dictionary) -> Dictionary:
	var reasons: Array[String] = []
	if not _config_valid(config):
		reasons.append("CONTACT_SUPPORT_CONFIG_INVALID")

	var identity := _observation_identity(observation, reasons)
	if _config_valid(config) \
			and String(identity["sample_phase"]) != String(config["sample_phase"]):
		reasons.append("OBSERVATION_SAMPLE_PHASE_NOT_CONFIGURED_PHASE")

	var qualification_value: Variant = observation.get("ground_qualification")
	var qualification: Dictionary = {}
	if qualification_value is Dictionary:
		qualification = qualification_value
	else:
		reasons.append("GROUND_QUALIFICATION_MISSING")
	if not qualification.is_empty():
		if String(qualification.get("schema_version", "")) \
				!= GroundQualifierScript.RESULT_SCHEMA_VERSION:
			reasons.append("GROUND_QUALIFICATION_SCHEMA_UNSUPPORTED")
		if typeof(qualification.get("observation_valid")) != TYPE_BOOL \
				or not bool(qualification.get("observation_valid", false)):
			reasons.append("GROUND_QUALIFICATION_INVALID")
		if typeof(qualification.get("qualifies_as_ground")) != TYPE_BOOL:
			reasons.append("GROUND_QUALIFICATION_DECISION_INVALID")
		if String(qualification.get("config_digest_sha256", "")) \
				!= String(config.get(
					"ground_qualifier_config_digest_sha256", "")):
			reasons.append("GROUND_QUALIFICATION_CONFIG_MISMATCH")
		if int(qualification.get("physics_step_id", -2)) \
				!= int(identity["physics_step_id"]) \
				or int(qualification.get("capture_epoch", -2)) \
					!= int(identity["capture_epoch"]) \
				or String(qualification.get("sample_phase", "")) \
					!= String(identity["sample_phase"]):
			reasons.append("GROUND_QUALIFICATION_TEMPORAL_IDENTITY_MISMATCH")
		if qualification.get("input_provenance") \
				!= identity.get("provenance"):
			reasons.append("GROUND_QUALIFICATION_PROVENANCE_MISMATCH")

	var load_status := _available_float_status(
		observation,
		"normal_load_available",
		"normal_load_n",
		"NORMAL_LOAD",
		reasons)
	_validate_quality(
		observation,
		"normal_load_quality",
		bool(load_status["available"]),
		config.get("accepted_normal_load_qualities", []),
		"NORMAL_LOAD_QUALITY_INVALID",
		reasons)
	var separation_status := _available_float_status(
		observation,
		"relative_separation_velocity_available",
		"relative_separation_velocity_mps",
		"RELATIVE_SEPARATION_VELOCITY",
		reasons)
	_validate_quality(
		observation,
		"relative_separation_velocity_quality",
		bool(separation_status["available"]),
		config.get("accepted_separation_velocity_qualities", []),
		"RELATIVE_SEPARATION_VELOCITY_QUALITY_INVALID",
		reasons)

	return {
		"valid": reasons.is_empty(),
		"reasons": reasons,
		"identity": identity,
		"qualifies_as_ground": bool(
			qualification.get("qualifies_as_ground", false)),
		"contact_patch_id": String(
			qualification.get("contact_patch_id", "")),
		"normal_load_quality": _stable_text(
			observation.get("normal_load_quality")),
		"relative_separation_velocity_quality": _stable_text(
			observation.get(
				"relative_separation_velocity_quality")),
		"normal_load_available": load_status["available"],
		"normal_load_n": load_status["value"],
		"relative_separation_velocity_available":
			separation_status["available"],
		"relative_separation_velocity_mps": separation_status["value"],
	}


static func _predecessor_reasons(
		config: Dictionary,
		previous: Dictionary,
		identity: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	if String(previous.get("schema_version", "")) != RESULT_SCHEMA_VERSION:
		reasons.append("SUPPORT_PREDECESSOR_SCHEMA_UNSUPPORTED")
	if not bool(previous.get("finite", false)):
		reasons.append("SUPPORT_PREDECESSOR_INVALID")
	if String(previous.get("support_id", "")) \
			!= String(config.get("support_id", "")):
		reasons.append("SUPPORT_PREDECESSOR_IDENTITY_MISMATCH")
	if String(previous.get("config_digest_sha256", "")) \
			!= String(config.get("config_digest_sha256", "")):
		reasons.append("SUPPORT_PREDECESSOR_CONFIG_MISMATCH")
	if not VALID_STATES.has(String(previous.get("support_state", ""))):
		reasons.append("SUPPORT_PREDECESSOR_STATE_INVALID")
	if not previous.get("counters") is Dictionary:
		reasons.append("SUPPORT_PREDECESSOR_COUNTERS_INVALID")
	else:
		var counters: Dictionary = previous["counters"]
		for field in _initial_counters().keys():
			if typeof(counters.get(field)) != TYPE_INT or int(counters[field]) < 0:
				reasons.append("SUPPORT_PREDECESSOR_COUNTERS_INVALID")
				break
	if int(previous.get("physics_step_id", -2)) + 1 \
			!= int(identity.get("physics_step_id", -1)):
		reasons.append("PHYSICS_STEP_NOT_EXACT_PREDECESSOR")
	if int(previous.get("capture_epoch", -2)) + 1 \
			!= int(identity.get("capture_epoch", -1)):
		reasons.append("CAPTURE_EPOCH_NOT_EXACT_PREDECESSOR")
	if String(previous.get("sample_phase", "")) \
			!= String(identity.get("sample_phase", "")):
		reasons.append("SAMPLE_PHASE_CHANGED")
	var previous_provenance: Variant = previous.get("input_provenance")
	var current_provenance: Variant = identity.get("provenance")
	if not previous_provenance is Dictionary \
			or not current_provenance is Dictionary \
			or previous_provenance != current_provenance:
		reasons.append("SUPPORT_PREDECESSOR_PROVENANCE_MISMATCH")
	return reasons


static func _seal_result(
		config: Dictionary,
		status: Dictionary,
		state: String,
		previous_state: String,
		transitioned: bool,
		reason: String,
		counters: Dictionary,
		release_requested: bool) -> Dictionary:
	var identity: Dictionary = status["identity"]
	return FrozenValueScript.snapshot({
		"schema_version": RESULT_SCHEMA_VERSION,
		"config_schema_version": String(config.get("schema_version", "")),
		"config_digest_sha256": String(
			config.get("config_digest_sha256", "")),
		"support_id": String(config.get("support_id", "")),
		"physics_step_id": int(identity["physics_step_id"]),
		"capture_epoch": int(identity["capture_epoch"]),
		"sample_phase": String(identity["sample_phase"]),
		"input_provenance": identity["provenance"],
		"finite": true,
		"requires_reinitialize": false,
		"support_state": state,
		"previous_support_state": previous_state,
		"support_guaranteed": state == BEARING,
		"transitioned": transitioned,
		"transition_reason": reason,
		"invalid_reasons": [],
		"ground_qualified": bool(status["qualifies_as_ground"]),
		"contact_patch_id": String(status["contact_patch_id"]),
		"normal_load_available": bool(status["normal_load_available"]),
		"normal_load_n": (
			float(status["normal_load_n"])
			if bool(status["normal_load_available"])
			else null),
		"normal_load_quality": (
			String(status["normal_load_quality"])
			if bool(status["normal_load_available"])
			else "unavailable"),
		"relative_separation_velocity_available": bool(
			status["relative_separation_velocity_available"]),
		"relative_separation_velocity_mps": (
			float(status["relative_separation_velocity_mps"])
			if bool(status["relative_separation_velocity_available"])
			else null),
		"relative_separation_velocity_quality": (
			String(status["relative_separation_velocity_quality"])
			if bool(status["relative_separation_velocity_available"])
			else "unavailable"),
		"release_requested": release_requested,
		"counters": counters,
		"geometry_fields_consulted": [],
	})


static func _invalid_result(
		config: Dictionary,
		previous: Dictionary,
		identity: Dictionary,
		reasons: Array[String],
		state: String) -> Dictionary:
	var previous_state := String(previous.get("support_state", "UNINITIALIZED"))
	var counters := _initial_counters()
	if previous.get("counters") is Dictionary:
		counters = (previous["counters"] as Dictionary).duplicate(true)
		counters["update_count"] = int(counters.get("update_count", 0)) + 1
	var transitioned := previous_state != state \
		and previous_state != "UNINITIALIZED"
	if transitioned:
		counters["state_age_ticks"] = 1
		counters["transition_count"] = int(
			counters.get("transition_count", 0)) + 1
		_update_transition_counters(
			counters, previous_state, state, true)
	return FrozenValueScript.snapshot({
		"schema_version": RESULT_SCHEMA_VERSION,
		"config_schema_version": String(config.get("schema_version", "")),
		"config_digest_sha256": String(
			config.get("config_digest_sha256", "")),
		"support_id": String(config.get("support_id", "")),
		"physics_step_id": int(identity.get("physics_step_id", -1)),
		"capture_epoch": int(identity.get("capture_epoch", -1)),
		"sample_phase": String(identity.get("sample_phase", "")),
		"input_provenance": identity.get("provenance", {}),
		"finite": false,
		"requires_reinitialize": true,
		"support_state": state,
		"previous_support_state": previous_state,
		"support_guaranteed": false,
		"transitioned": transitioned,
		"transition_reason": String(reasons[0]) if not reasons.is_empty() else "INVALID",
		"invalid_reasons": reasons,
		"ground_qualified": false,
		"contact_patch_id": "",
		"normal_load_available": false,
		"normal_load_n": null,
		"normal_load_quality": "unavailable",
		"relative_separation_velocity_available": false,
		"relative_separation_velocity_mps": null,
		"relative_separation_velocity_quality": "unavailable",
		"release_requested": false,
		"counters": counters,
		"geometry_fields_consulted": [],
	})


static func _update_transition_counters(
		counters: Dictionary,
		previous_state: String,
		next_state: String,
		transitioned: bool) -> void:
	if not transitioned:
		return
	if next_state == TOUCH and previous_state in [SEARCH, LOST]:
		counters["touchdown_count"] = int(counters["touchdown_count"]) + 1
	if next_state == LOAD:
		counters["load_entry_count"] = int(counters["load_entry_count"]) + 1
	if next_state == BEARING:
		counters["bearing_entry_count"] = int(counters["bearing_entry_count"]) + 1
	if next_state == UNLOAD:
		counters["unload_entry_count"] = int(counters["unload_entry_count"]) + 1
	if next_state == LOST:
		counters["lost_entry_count"] = int(counters["lost_entry_count"]) + 1


static func _initial_counters() -> Dictionary:
	return {
		"update_count": 1,
		"state_age_ticks": 1,
		"transition_count": 0,
		"qualified_contact_ticks": 0,
		"load_ready_ticks": 0,
		"load_unavailable_ticks": 0,
		"separation_unavailable_ticks": 0,
		"touchdown_count": 0,
		"load_entry_count": 0,
		"bearing_entry_count": 0,
		"unload_entry_count": 0,
		"lost_entry_count": 0,
	}


static func _observation_identity(
		observation: Dictionary,
		reasons: Array[String]) -> Dictionary:
	var step_valid := typeof(observation.get("physics_step_id")) == TYPE_INT \
		and int(observation.get("physics_step_id")) >= 0
	var epoch_valid := typeof(observation.get("capture_epoch")) == TYPE_INT \
		and int(observation.get("capture_epoch")) >= 0
	var phase_value: Variant = observation.get("sample_phase")
	var phase_valid := (phase_value is String or phase_value is StringName) \
		and String(phase_value) in VALID_SAMPLE_PHASES
	var provenance := {}
	for field in [
		"run_id",
		"capture_stream_id",
		"observer_profile_id",
		"observer_adapter_id",
	]:
		var value: Variant = observation.get(field)
		if not (value is String or value is StringName) \
				or String(value).is_empty():
			reasons.append("OBSERVATION_%s_INVALID" % field.to_upper())
		else:
			provenance[field] = String(value)
	if not step_valid:
		reasons.append("OBSERVATION_PHYSICS_STEP_INVALID")
	if not epoch_valid:
		reasons.append("OBSERVATION_CAPTURE_EPOCH_INVALID")
	if not phase_valid:
		reasons.append("OBSERVATION_SAMPLE_PHASE_INVALID")
	return {
		"physics_step_id": int(observation.get("physics_step_id", -1)),
		"capture_epoch": int(observation.get("capture_epoch", -1)),
		"sample_phase": String(observation.get("sample_phase", "")),
		"provenance": provenance,
	}


static func _available_float_status(
		observation: Dictionary,
		available_field: String,
		value_field: String,
		code_prefix: String,
		reasons: Array[String]) -> Dictionary:
	if typeof(observation.get(available_field)) != TYPE_BOOL:
		reasons.append("%s_AVAILABILITY_INVALID" % code_prefix)
		return {"available": false, "value": 0.0}
	var available := bool(observation[available_field])
	if not available:
		return {"available": false, "value": 0.0}
	var value: Variant = observation.get(value_field)
	if not (value is float or value is int) or not is_finite(float(value)):
		reasons.append("%s_VALUE_INVALID" % code_prefix)
		return {"available": true, "value": 0.0}
	return {"available": true, "value": float(value)}


static func _config_valid(config: Dictionary) -> bool:
	var structurally_valid: bool = String(config.get("schema_version", "")) \
			== CONFIG_SCHEMA_VERSION \
		and not String(config.get("support_id", "")).is_empty() \
		and not String(config.get("sample_phase", "")).is_empty() \
		and int(config.get("contact_confirm_ticks", 0)) > 0 \
		and int(config.get("bearing_confirm_ticks", 0)) > 0 \
		and is_finite(float(config.get("bearing_enter_load_n", NAN))) \
		and is_finite(float(config.get("bearing_exit_load_n", NAN))) \
		and is_finite(float(config.get("unloaded_load_n", NAN))) \
			and is_finite(float(
			config.get("maximum_separating_speed_mps", NAN))) \
			and _is_sha256_digest(String(config.get(
				"ground_qualifier_config_digest_sha256", ""))) \
			and config.get("accepted_normal_load_qualities") is Array \
			and not (config.get(
				"accepted_normal_load_qualities") as Array).is_empty() \
			and config.get(
				"accepted_separation_velocity_qualities") is Array \
			and not (config.get(
				"accepted_separation_velocity_qualities") as Array).is_empty()
	if not structurally_valid:
		return false
	var digest := String(config.get("config_digest_sha256", ""))
	var payload := config.duplicate(true)
	payload.erase("config_digest_sha256")
	return _is_sha256_digest(digest) \
		and digest == CanonicalJsonScript.sha256(payload)


static func _stable_name(
		value: Variant,
		path: String,
		errors: Array[Dictionary]) -> String:
	if (value is String or value is StringName) and not String(value).is_empty():
		return String(value)
	_add_error(
		errors,
		"STABLE_NAME_INVALID",
		path,
		"Expected a nonempty stable String/StringName")
	return ""


static func _stable_text(value: Variant) -> String:
	return String(value) if value is String or value is StringName else ""


static func _positive_integer(
		value: Variant,
		path: String,
		errors: Array[Dictionary]) -> int:
	if typeof(value) == TYPE_INT and int(value) > 0:
		return int(value)
	_add_error(
		errors,
		"POSITIVE_INTEGER_INVALID",
		path,
		"Expected a positive integer")
	return 0


static func _finite_float(
		value: Variant,
		path: String,
		errors: Array[Dictionary]) -> float:
	if (value is float or value is int) and is_finite(float(value)):
		return float(value)
	_add_error(
		errors,
		"FINITE_FLOAT_INVALID",
		path,
		"Expected a finite number")
	return 0.0


static func _sha256_digest(
		value: Variant,
		path: String,
		errors: Array[Dictionary]) -> String:
	var digest := String(value) \
		if value is String or value is StringName else ""
	if _is_sha256_digest(digest):
		return digest
	_add_error(
		errors,
		"SHA256_DIGEST_INVALID",
		path,
		"Expected a lowercase sha256: digest")
	return ""


static func _is_sha256_digest(value: String) -> bool:
	if value.length() != 71 or not value.begins_with("sha256:"):
		return false
	for index in range(7, value.length()):
		if value.substr(index, 1) not in "0123456789abcdef":
			return false
	return true


static func _validate_quality(
		observation: Dictionary,
		field: String,
		available: bool,
		allowed_value: Variant,
		error_code: String,
		reasons: Array[String]) -> void:
	var quality: Variant = observation.get(field)
	if not available:
		if quality != "unavailable":
			reasons.append(error_code)
		return
	if not (quality is String or quality is StringName) \
			or not allowed_value is Array \
			or not (allowed_value as Array).has(String(quality)):
		reasons.append(error_code)


static func _add_error(
		errors: Array[Dictionary],
		code: String,
		path: String,
		message: String) -> void:
	errors.append({"code": code, "path": path, "message": message})
