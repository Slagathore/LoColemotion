class_name LabBraceDetectionAnalyzer
extends RefCounted
# gdlint: disable=max-line-length

## Digest-bound BR8 detector commissioning contract.
##
## Positive scope: early loss-of-viability classification in the declared
## planar-scaffold passive disturbance matrix. This is detector evidence only;
## no active brace, stepping, fall arrest, free-3D standing, or locomotion.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA_VERSION := "brace_detection_configuration_v1"
const CLAIM_BOUNDARY := (
	"BR8 early loss-of-viability detection in an explicit passive planar-scaffold "
	+ "matrix: exact static and linear-capture margin oracles; decomposed boundary "
	+ "and impact clocks; immediate STAND/PRECARIOUS/BRACE escalation with "
	+ "hysteretic one-state-at-a-time release; one central horizontal rigid-body "
	+ "impulse; one slowly tilting ordinary platform; one removal of an ordinary "
	+ "right support; and a delayed REACTION_TOO_LATE negative control. The "
	+ "detector and supervisor observe only and apply no force, torque, foot pin, "
	+ "root rescue, brace, step, creature edit, or automatic guidance. This "
	+ "establishes no executed brace, articulated brace controller, free 3D "
	+ "standing or balance, fall arrest, getting up, gait, or walking."
)
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"physics_hz",
	"impulse_tick",
	"impulse_total_ticks",
	"impulse_n_s",
	"tilt_start_tick",
	"tilt_ramp_ticks",
	"tilt_total_ticks",
	"tilt_maximum_angle_rad",
	"support_loss_tick",
	"support_loss_total_ticks",
	"brace_margin_m",
	"precarious_margin_m",
	"release_margin_m",
	"reaction_time_s",
	"safety_time_s",
	"brace_trigger_time_s",
	"precarious_trigger_time_s",
	"release_dwell_ticks",
	"planar_guide_enabled",
	"guide_motors_enabled",
	"guide_springs_enabled",
	"active_brace_controller_enabled",
	"step_controller_enabled",
	"root_rescue_enabled",
	"automatic_creature_guidance_enabled",
	"free_3d_standing_claim_enabled",
]
const POSITIVE_INTEGER_FIELDS: Array[String] = [
	"physics_hz",
	"impulse_tick",
	"impulse_total_ticks",
	"tilt_start_tick",
	"tilt_ramp_ticks",
	"tilt_total_ticks",
	"support_loss_tick",
	"support_loss_total_ticks",
	"release_dwell_ticks",
]
const POSITIVE_NUMERIC_FIELDS: Array[String] = [
	"impulse_n_s",
	"tilt_maximum_angle_rad",
	"precarious_margin_m",
	"release_margin_m",
	"reaction_time_s",
	"brace_trigger_time_s",
	"precarious_trigger_time_s",
]
const FORBIDDEN_TRUE_FIELDS: Array[String] = [
	"guide_motors_enabled",
	"guide_springs_enabled",
	"active_brace_controller_enabled",
	"step_controller_enabled",
	"root_rescue_enabled",
	"automatic_creature_guidance_enabled",
	"free_3d_standing_claim_enabled",
]


static func build(configuration: Dictionary) -> Dictionary:
	var keys: Array = configuration.keys()
	keys.sort()
	var expected: Array = REQUIRED_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		return _failure("BRACE_DETECTION_CONFIGURATION_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != SCHEMA_VERSION:
		return _failure("BRACE_DETECTION_CONFIGURATION_SCHEMA_UNSUPPORTED")
	for field in POSITIVE_INTEGER_FIELDS:
		var value: Variant = configuration.get(field)
		if (
			typeof(value) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(value))
			or float(value) != floorf(float(value))
			or int(value) <= 0
		):
			return _failure("BRACE_DETECTION_POSITIVE_INTEGER_INVALID:%s" % field)
	for field in POSITIVE_NUMERIC_FIELDS:
		var value: Variant = configuration.get(field)
		if (
			typeof(value) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(value))
			or float(value) <= 0.0
		):
			return _failure("BRACE_DETECTION_POSITIVE_VALUE_INVALID:%s" % field)
	for field in ["brace_margin_m", "safety_time_s"]:
		var value: Variant = configuration.get(field)
		if (
			typeof(value) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(value))
			or float(value) < 0.0
		):
			return _failure("BRACE_DETECTION_NONNEGATIVE_VALUE_INVALID:%s" % field)
	if (
		int(configuration["impulse_tick"]) >= int(configuration["impulse_total_ticks"])
		or (
			int(configuration["tilt_start_tick"]) + int(configuration["tilt_ramp_ticks"])
			> int(configuration["tilt_total_ticks"])
		)
		or int(configuration["support_loss_tick"]) >= int(configuration["support_loss_total_ticks"])
		or float(configuration["brace_margin_m"]) >= float(configuration["precarious_margin_m"])
		or float(configuration["precarious_margin_m"]) >= float(configuration["release_margin_m"])
		or (
			float(configuration["brace_trigger_time_s"])
			<= (float(configuration["reaction_time_s"]) + float(configuration["safety_time_s"]))
		)
		or (
			float(configuration["precarious_trigger_time_s"])
			<= float(configuration["brace_trigger_time_s"])
		)
	):
		return _failure("BRACE_DETECTION_CONFIGURATION_RANGE_INVALID")
	if (
		typeof(configuration.get("planar_guide_enabled")) != TYPE_BOOL
		or not bool(configuration["planar_guide_enabled"])
	):
		return _failure("BRACE_DETECTION_EXPLICIT_PLANAR_GUIDE_REQUIRED")
	for field in FORBIDDEN_TRUE_FIELDS:
		if typeof(configuration.get(field)) != TYPE_BOOL or bool(configuration[field]):
			return _failure("BRACE_DETECTION_FORBIDDEN_ASSIST_OR_CLAIM:%s" % field)
	var payload := configuration.duplicate(true)
	payload["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	payload["claim_boundary"] = CLAIM_BOUNDARY
	return {"ok": true, "contract": FrozenValueScript.snapshot(payload)}


static func analyze(contract: Dictionary, summary: Dictionary) -> Dictionary:
	if (
		String(contract.get("schema_version", "")) != SCHEMA_VERSION
		or String(contract.get("claim_boundary", "")) != CLAIM_BOUNDARY
		or not String(contract.get("configuration_sha256", "")).begins_with("sha256:")
	):
		return _failure("BRACE_DETECTION_CONTRACT_INVALID")
	if (
		String(summary.get("schema_version", "")) != "brace_detection_fixture_summary_v1"
		or not bool(summary.get("ok", false))
	):
		return _failure("BRACE_DETECTION_SUMMARY_INVALID")
	for field in ["impulse", "tilt", "support_loss"]:
		if typeof(summary.get(field)) != TYPE_DICTIONARY:
			return _failure("BRACE_DETECTION_SUMMARY_SECTION_MISSING:%s" % field)
	var impulse: Dictionary = summary["impulse"]
	var tilt: Dictionary = summary["tilt"]
	var support_loss: Dictionary = summary["support_loss"]
	if (
		not bool(impulse.get("complete", false))
		or not bool(tilt.get("complete", false))
		or not bool(support_loss.get("complete", false))
		or not bool(impulse.get("guide_exact", false))
		or not bool(tilt.get("guide_exact", false))
		or not bool(support_loss.get("guide_exact", false))
	):
		return _failure("BRACE_DETECTION_FIXTURE_INCOMPLETE")
	if (
		not bool(summary.get("planar_guide_declared", false))
		or bool(summary.get("guide_motors_enabled", true))
		or bool(summary.get("guide_springs_enabled", true))
		or bool(summary.get("active_brace_controller_present", true))
		or bool(summary.get("step_controller_present", true))
		or bool(summary.get("root_rescue_present", true))
		or bool(summary.get("automatic_creature_guidance", true))
	):
		return _failure("BRACE_DETECTION_HIDDEN_ASSIST_OR_GUIDANCE")
	if (
		int(impulse.get("impulse_operation_count", 0)) != 1
		or int(impulse.get("first_brace_tick", -1)) < int(contract["impulse_tick"])
		or int(impulse.get("first_brace_tick", -1)) > int(contract["impulse_tick"]) + 2
		or String(impulse.get("first_brace_reason", "")) != "CAPTURE_MARGIN_BRACE"
		or (
			float(impulse.get("first_brace_static_margin_m", -1.0))
			<= float(contract["brace_margin_m"])
		)
		or (
			float(impulse.get("first_brace_capture_margin_m", 1.0))
			> float(contract["brace_margin_m"])
		)
		or not bool(impulse.get("first_brace_reaction_viable", false))
	):
		return _failure("BRACE_DETECTION_IMPULSE_CAUSAL_GATE_FAILED")
	if (
		int(tilt.get("first_precarious_tick", -1)) < int(contract["tilt_start_tick"])
		or int(tilt.get("first_brace_tick", -1)) <= int(tilt.get("first_precarious_tick", -1))
		or float(tilt.get("first_brace_static_margin_m", -1.0)) < 0.0
		or (
			int(tilt.get("first_static_exhaustion_tick", -1)) >= 0
			and int(tilt["first_brace_tick"]) >= int(tilt["first_static_exhaustion_tick"])
		)
	):
		return _failure("BRACE_DETECTION_TILT_CAUSAL_GATE_FAILED")
	if (
		int(support_loss.get("support_removal_operation_count", 0)) != 1
		or (
			int(support_loss.get("first_loss_observed_tick", -1))
			< int(contract["support_loss_tick"])
		)
		or (
			int(support_loss.get("first_loss_observed_tick", -1))
			> int(contract["support_loss_tick"]) + 2
		)
		or (
			int(support_loss.get("first_brace_tick", -1))
			!= int(support_loss.get("first_loss_observed_tick", -2))
		)
		or int(support_loss.get("first_brace_support_count", -1)) != 1
		or String(support_loss.get("first_brace_reason", "")) != "STATIC_MARGIN_EXHAUSTED"
	):
		return _failure("BRACE_DETECTION_SUPPORT_LOSS_GATE_FAILED")
	return {
		"ok": true,
		"accepted": true,
		"claim_boundary": CLAIM_BOUNDARY,
		"milestone_cells": ["BR8.0", "BR8.1", "BR8.2", "BR8.3"],
		"integrity_cell": "BR8.4",
		"detector_observation_only": true,
		"active_brace_executed": false,
		"automatic_creature_guidance": false,
		"does_not_establish":
		[
			"existing_contact_brace",
			"catch_step",
			"free_3d_standing",
			"unconstrained_balance",
			"fall_arrest",
			"getting_up",
			"gait",
			"walking",
		],
	}


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
