extends SceneTree

## BR3A pure contract test: capacity is derived before observation, equality
## with the configured cap is already ambiguous/truncated evidence, and one
## saturated frame remains a run-wide invalidity witness after contact count
## falls again.

const ContactCapacityScript := preload(
	"res://scripts/lab/mechanics/contact_capacity.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== BR3A derived contact capacity and saturation ===")
	var built: Dictionary = ContactCapacityScript.derive({
		"body_id": "box_0",
		"expected_simultaneous_raw_points": 4,
		"safety_margin_raw_points": 4,
		"policy_max_cap_per_body": 32,
	})
	_check(bool(built["ok"]),
		"four expected points plus four margin points derives successfully")
	var capacity: Dictionary = built["capacity"]
	_check(int(capacity["configured_cap_per_body"]) == 8
		and String(capacity["derivation"]) == "expected_plus_safety_margin",
		"derived cap records its exact 4 + 4 = 8 provenance")

	var below := ContactCapacityScript.observe(capacity, 7)
	_check(bool(below["finite"])
		and not bool(below["saturated_now"])
		and int(below["remaining_reportable_slots"]) == 1,
		"count below cap remains measurable with one witnessed spare slot")

	var equal := ContactCapacityScript.observe(capacity, 8, 7)
	_check(not bool(equal["finite"])
		and bool(equal["saturated_now"])
		and bool(equal["saturated_ever"])
		and (equal["invalid_reasons"] as Array).has(
			"CONTACT_BUFFER_SATURATED"),
		"count equal to cap fails closed because truncation is unknowable")

	var later_quiet := ContactCapacityScript.observe(capacity, 2, 8)
	_check(not bool(later_quiet["finite"])
		and not bool(later_quiet["saturated_now"])
		and bool(later_quiet["saturated_ever"])
		and int(later_quiet["peak_observed_count"]) == 8,
		"later quiet frame preserves the earlier run-wide saturation witness")

	var exceeded := ContactCapacityScript.observe(capacity, 9)
	_check(not bool(exceeded["finite"])
		and bool(exceeded["saturated_now"]),
		"impossible count above configured cap is also invalid")

	var zero_expected := ContactCapacityScript.derive({
		"body_id": "box_0",
		"expected_simultaneous_raw_points": 0,
		"safety_margin_raw_points": 4,
	})
	_check(not bool(zero_expected["ok"])
		and _has_error(zero_expected, "EXPECTED_CONTACT_COUNT_INVALID"),
		"zero expected points cannot masquerade as a positive-contact profile")
	var zero_margin := ContactCapacityScript.derive({
		"body_id": "box_0",
		"expected_simultaneous_raw_points": 4,
		"safety_margin_raw_points": 0,
	})
	_check(not bool(zero_margin["ok"])
		and _has_error(zero_margin, "CONTACT_MARGIN_INVALID"),
		"positive-contact evidence requires a nonzero preregistered margin")
	var policy_overflow := ContactCapacityScript.derive({
		"body_id": "microtoe_pack",
		"expected_simultaneous_raw_points": 100,
		"safety_margin_raw_points": 32,
		"policy_max_cap_per_body": 128,
	})
	_check(not bool(policy_overflow["ok"])
		and _has_error(policy_overflow, "DERIVED_CONTACT_CAP_EXCEEDS_POLICY"),
		"derived cap cannot silently exceed the declared implementation policy")
	_finish()


func _has_error(result: Dictionary, code: String) -> bool:
	for error_value in result.get("errors", []):
		var error: Dictionary = error_value
		if String(error.get("code", "")) == code:
			return true
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
