extends SceneTree

## M38 — Mode-aware credibility. Universal cheat-proof floor + per-mode gestures, with the
## strict walk gate preserved unchanged. Reserved swim/fly/climb return unsupported_mode.

const SR := preload("res://scripts/sim/sim_rollout.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _run() -> void:
	print("=== M38 mode-aware credibility tests ===")
	_test_walk_gate_unchanged()
	_test_mode_positives()
	_test_universal_floor_binds_every_mode()
	_test_reserved_mode_returns_unsupported()
	_test_detect_mode_from_behaviour()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


# Baseline credible-walk measured dict; merge overrides per case.
func _m(over: Dictionary) -> Dictionary:
	var b := {
		"ok": true, "forward": 5.0, "forward_tail": 2.0, "straightness": 0.9, "yaw_delta": 0.1,
		"root_up_min": 0.9, "root_height_drop": 0.1, "assist_per_meter": 50.0, "assist_ratio": 0.3,
		"lateral_ratio": 0.1, "yaw_rate": 0.3, "theta_span": 1.0, "max_omega": 1.0,
		"slip_ratio": 0.1, "assist_ratio_ceiling": SR.MAX_ASSIST_RATIO,
		"slip_ratio_ceiling": SR.MAX_SLIP_RATIO, "teleport": false,
		"spring_energy_stored": 1.0, "spring_energy_released": 0.5,
		"distance_abs": 5.0, "bounce": 0.0, "bounce_ratio": 0.0, "lateral": 0.0, "fell": false,
	}
	b.merge(over, true)
	return b


func _test_walk_gate_unchanged() -> void:
	print("- walk gesture == the strict classify_locomotion gate (unchanged)")
	var fixtures := [
		{"over": {}, "credible": true, "class": "credible_walk"},
		{"over": {"root_up_min": 0.2}, "credible": false, "class": "fall_or_tip"},
		{"over": {"forward": 1.2}, "credible": false, "class": "too_short"},
		{"over": {"lateral_ratio": 0.85}, "credible": false, "class": "skate_or_spin"},
	]
	for f in fixtures:
		var m: Dictionary = _m(f["over"])
		var strict := SR.classify_locomotion(m["forward"], m["forward_tail"], m["straightness"],
			m["yaw_delta"], m["root_up_min"], m["root_height_drop"], m["ok"],
			m["assist_per_meter"], m["assist_ratio"], m["lateral_ratio"], m["yaw_rate"],
			m["theta_span"], m["max_omega"])
		var gesture := SR.classify_mode(&"walk", m)
		_check(bool(strict["credible_walk"]) == bool(f["credible"]),
			"strict gate credible matches expectation (%s)" % String(f["class"]))
		_check(bool(gesture["credible"]) == bool(strict["credible_walk"])
			and String(gesture["class"]) == String(strict["class"]),
			"walk gesture mirrors the strict gate (%s)" % String(f["class"]))


func _test_mode_positives() -> void:
	print("- one positive per implemented mode")
	var walk := SR.classify_mode(&"walk", _m({}))
	_check(bool(walk["credible"]) and walk["class"] == &"credible_walk", "walk positive")

	var hop := SR.classify_mode(&"hop", _m({"forward": 3.0, "bounce": 0.4, "bounce_ratio": 0.8,
		"theta_span": 0.5, "max_omega": 1.0, "straightness": 0.2, "yaw_delta": 1.2}))
	_check(bool(hop["credible"]) and hop["class"] == &"hopped",
		"hop positive (relaxed yaw/straightness, requires flight phase)")

	var lat := SR.classify_mode(&"lateral", _m({"lateral": 4.0, "lateral_ratio": 0.8,
		"forward": 0.5, "theta_span": 0.5, "max_omega": 1.0}))
	_check(bool(lat["credible"]) and lat["class"] == &"lateral_scuttle", "lateral positive")

	var roll := SR.classify_mode(&"roll", _m({"distance_abs": 4.0, "yaw_rate": 5.0,
		"root_up_min": 0.1, "slip_ratio": 3.0}))
	_check(bool(roll["credible"]) and roll["class"] == &"rolled",
		"roll positive (spin allowed, slip-exempt, low CoM)")

	var und := SR.classify_mode(&"undulation", _m({"distance_abs": 4.0, "theta_span": 0.5,
		"max_omega": 1.0, "slip_ratio": 3.0}))
	_check(bool(und["credible"]) and und["class"] == &"undulated",
		"undulation positive (foot-clearance + slip exempt)")

	var pogo := SR.classify_mode(&"pogo", _m({"distance_abs": 2.0, "slip_ratio": 3.0}))
	_check(bool(pogo["credible"]) and pogo["class"] == &"pogo_drift", "pogo positive (measured-only)")


func _test_universal_floor_binds_every_mode() -> void:
	print("- the universal floor rejects every mode (teleport + non-conservative spring)")
	var tp := _m({"teleport": true})
	_check(not bool(SR.classify_mode(&"walk", tp)["credible"]), "teleport fails walk")
	_check(not bool(SR.classify_mode(&"hop", _m({"teleport": true, "forward": 3.0, "bounce": 0.4,
		"theta_span": 0.5, "max_omega": 1.0}))["credible"]), "teleport fails hop")
	var cheat_spring := _m({"spring_energy_stored": 1.0, "spring_energy_released": 3.0})
	var v := SR.classify_mode(&"walk", cheat_spring)
	_check(not bool(v["credible"]) and (v["reasons"] as Array).has("spring returned more than it stored"),
		"a spring that returns more than it stored fails the floor")
	# roll is slip-exempt but NOT teleport-exempt.
	_check(not bool(SR.classify_mode(&"roll", _m({"distance_abs": 4.0, "teleport": true})) ["credible"]),
		"teleport fails roll too (floor is universal)")


func _test_reserved_mode_returns_unsupported() -> void:
	print("- reserved swim/climb dispatch to unsupported_mode (fly/glide now implemented, M52)")
	for mode in [&"swim", &"climb"]:
		var v := SR.classify_mode(mode, _m({}))
		_check(not bool(v["credible"]) and v["class"] == &"unsupported_mode",
			"%s -> unsupported_mode" % String(mode))
	# M52: fly is now a real gesture, not unsupported.
	var fly := SR.classify_mode(&"fly", _m({"distance_abs": 5.0}))
	_check(fly["class"] != &"unsupported_mode" and bool(fly["credible"]),
			"fly is implemented (a translating flight is credible)")


func _test_detect_mode_from_behaviour() -> void:
	print("- achieved mode is detected from behaviour, not the track")
	_check(SR.detect_mode(_m({})) == &"walk", "default behaviour detects walk")
	_check(SR.detect_mode(_m({"yaw_rate": 5.0, "root_up_min": 0.1})) == &"roll",
		"spin at low CoM detects roll")
	_check(SR.detect_mode(_m({"bounce_ratio": 0.8})) == &"hop", "vertical excursion detects hop")
	_check(SR.detect_mode(_m({"lateral_ratio": 0.8})) == &"lateral", "sideways detects lateral")
