extends SceneTree

## Exploit gauntlet: the credibility classifier must REJECT every way training will
## try to cheat forward progress, for the right reason. A credible baseline must pass.
## (Boundary tests of SimRollout.classify_locomotion — the single shared verdict the
## trainer/optimizer/reconcile all read.)

const SR := preload("res://scripts/sim/sim_rollout.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Locomotion exploit gauntlet ===")
	# A genuine credible walk (the positive control).
	var good := _c({})
	_check(bool(good["credible_walk"]) and String(good["class"]) == "credible_walk",
			"a real walk passes the gate")

	# Each cheat flips ONE metric past its gate; assert rejected + correct class + reason.
	_reject("falling-forward (tipped)", {"root_up_min": 0.2}, "fall_or_tip", "root tipped over")
	_reject("biped collapse (sank)", {"root_height_drop": 1.5}, "fall_or_tip", "root height collapsed")
	_reject("sideways skater", {"lateral_ratio": 0.85}, "skate_or_spin", "sideways skating")
	_reject("spinner", {"yaw_rate": 3.0}, "skate_or_spin", "spinning")
	_reject("rigid skate (no leg motion)", {"theta_span": 0.0, "max_omega": 0.0},
			"assist_carried", "rigid (no leg motion)")
	_reject("lurch-then-jam", {"forward_tail": 0.4}, "lurch_or_jam", "back-half progress below 1.25m")
	_reject("too short", {"forward": 1.2}, "too_short", "forward distance below 3.0m")
	_reject("assist-per-meter jitter", {"assist_per_meter": 9000.0}, "assist_carried",
			"assist per meter above budget")
	# M37: feet that slide far while the body barely advances = lean-and-slide skating,
	# invisible to assist_ratio. slip_ratio over its ceiling must reject for the right reason.
	_reject("lean-and-slide skater", {"slip_ratio": SR.MAX_SLIP_RATIO + 1.0},
			"skate_or_spin", "slip_or_skid")

	# A cheat must never out-rank a credible walk via any single exploited axis.
	_check(not bool(_c({"lateral_ratio": 0.85})["credible_walk"])
			and not bool(_c({"yaw_rate": 3.0})["credible_walk"])
			and not bool(_c({"theta_span": 0.0})["credible_walk"]),
			"skater/spinner/rigid-ride are all non-credible")

	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


# Classify a healthy-walk baseline with the given field overrides.
func _c(over: Dictionary) -> Dictionary:
	var b := {"forward": 5.0, "forward_tail": 2.0, "straightness": 0.9, "yaw_delta": 0.1,
		"root_up_min": 0.9, "root_height_drop": 0.1, "finite": true,
		"assist_per_meter": 50.0, "assist_ratio": 0.3,
		"lateral_ratio": 0.1, "yaw_rate": 0.3, "theta_span": 1.0, "max_omega": 1.0,
		"slip_ratio": 0.1}
	b.merge(over, true)
	return SR.classify_locomotion(b["forward"], b["forward_tail"], b["straightness"], b["yaw_delta"],
		b["root_up_min"], b["root_height_drop"], b["finite"], b["assist_per_meter"], b["assist_ratio"],
		b["lateral_ratio"], b["yaw_rate"], b["theta_span"], b["max_omega"],
		SR.MAX_ASSIST_RATIO, b["slip_ratio"], SR.MAX_SLIP_RATIO)


func _reject(label: String, over: Dictionary, want_class: String, want_reason: String) -> void:
	var r := _c(over)
	var ok := not bool(r["credible_walk"]) and String(r["class"]) == want_class \
			and (r["reasons"] as Array).has(want_reason)
	if not ok:
		printerr("    got class=%s reasons=%s" % [String(r["class"]), str(r["reasons"])])
	_check(ok, "%s -> rejected as %s" % [label, want_class])
