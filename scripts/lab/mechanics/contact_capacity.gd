class_name LabContactCapacity
extends RefCounted

## BR3A contact-buffer capacity contract.
##
## Godot/Jolt exposes at most `max_contacts_reported` points for one body. If
## the observer sees exactly that many points, it cannot distinguish "there
## were exactly cap points" from "there were more and the buffer truncated
## them." Therefore count >= cap is saturated and INVALID evidence. A later
## quiet frame does not erase the loss: `peak_observed_count` carries the
## saturation witness for the complete run.
##
## The cap is derived from a fixture/morphology declaration rather than tuned
## after observing the result:
##
##     configured_cap = expected_simultaneous_raw_points + safety_margin
##
## Both inputs, the policy ceiling, and the exact saturation rule are emitted
## with every value so an encyclopedia finding can reproduce its observation
## envelope instead of inheriting a hidden magic number.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const FailureCodesScript := preload("res://scripts/lab/failure_codes.gd")

const SCHEMA_VERSION := "contact_capacity_v1"
const DEFAULT_POLICY_MAX_CAP_PER_BODY := 256


static func derive(configuration: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	var body_id := String(configuration.get("body_id", ""))
	if body_id.is_empty():
		_add_error(errors, "BODY_ID_EMPTY", "/body_id",
			"Capacity derivation requires a stable body_id")

	var expected_value: Variant = configuration.get(
		"expected_simultaneous_raw_points")
	var margin_value: Variant = configuration.get("safety_margin_raw_points")
	var policy_max_value: Variant = configuration.get(
		"policy_max_cap_per_body", DEFAULT_POLICY_MAX_CAP_PER_BODY)
	var expected_points := _positive_integer(
		expected_value,
		"EXPECTED_CONTACT_COUNT_INVALID",
		"/expected_simultaneous_raw_points",
		errors)
	var safety_margin := _positive_integer(
		margin_value,
		"CONTACT_MARGIN_INVALID",
		"/safety_margin_raw_points",
		errors)
	var policy_max := _positive_integer(
		policy_max_value,
		"CONTACT_POLICY_MAX_INVALID",
		"/policy_max_cap_per_body",
		errors)
	var configured_cap := expected_points + safety_margin
	if policy_max > 0 and configured_cap > policy_max:
		_add_error(errors, "DERIVED_CONTACT_CAP_EXCEEDS_POLICY",
			"/policy_max_cap_per_body",
			"Derived cap %d exceeds the declared policy ceiling %d"
				% [configured_cap, policy_max])

	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	return {
		"ok": true,
		"errors": [],
		"capacity": FrozenValueScript.snapshot({
			"schema_version": SCHEMA_VERSION,
			"body_id": body_id,
			"expected_simultaneous_raw_points": expected_points,
			"safety_margin_raw_points": safety_margin,
			"configured_cap_per_body": configured_cap,
			"policy_max_cap_per_body": policy_max,
			"derivation": "expected_plus_safety_margin",
			"saturation_rule": "observed_count_greater_or_equal_cap_invalid",
		}),
	}


static func observe(
		capacity: Dictionary,
		observed_count: int,
		previous_peak_observed_count: int = 0) -> Dictionary:
	var invalid_reasons: Array[String] = []
	if String(capacity.get("schema_version", "")) != SCHEMA_VERSION:
		invalid_reasons.append("CONTACT_CAPACITY_SCHEMA_UNSUPPORTED")
	var configured_cap := int(capacity.get("configured_cap_per_body", 0))
	if configured_cap <= 0:
		invalid_reasons.append("CONTACT_CAPACITY_INVALID")
	if observed_count < 0 or previous_peak_observed_count < 0:
		invalid_reasons.append("CONTACT_COUNT_INVALID")
	var peak_observed_count := maxi(
		observed_count, previous_peak_observed_count)
	var saturated_now := configured_cap > 0 and observed_count >= configured_cap
	var saturated_ever := configured_cap > 0 \
		and peak_observed_count >= configured_cap
	if saturated_ever:
		invalid_reasons.append(FailureCodesScript.CONTACT_BUFFER_SATURATED)
	var finite := invalid_reasons.is_empty()
	return FrozenValueScript.snapshot({
		"schema_version": "contact_capacity_observation_v1",
		"body_id": String(capacity.get("body_id", "")),
		"configured_cap_per_body": configured_cap,
		"observed_count": observed_count,
		"peak_observed_count": peak_observed_count,
		"remaining_reportable_slots": (
			maxi(configured_cap - observed_count, 0)
			if configured_cap > 0 and observed_count >= 0
			else null),
		"saturated_now": saturated_now,
		"saturated_ever": saturated_ever,
		"finite": finite,
		"invalid_reasons": invalid_reasons.duplicate(),
		"availability": {
			"/contacts": {
				"status": "measured" if finite else "invalid",
				"reason": null if finite else "; ".join(invalid_reasons),
				"source": SCHEMA_VERSION,
			},
		},
	})


static func _positive_integer(
		value: Variant,
		code: String,
		path: String,
		errors: Array[Dictionary]) -> int:
	if value is int and int(value) > 0:
		return int(value)
	_add_error(errors, code, path, "Expected a positive integer")
	return 0


static func _add_error(
		errors: Array[Dictionary],
		code: String,
		path: String,
		message: String) -> void:
	errors.append({"code": code, "path": path, "message": message})
