extends SceneTree

## M37 — Slip gate. assist_ratio catches creatures riding the *named* assists; it is
## blind to a creature that leans and slides on ground reaction. slip_ratio is the
## per-foot stance-slide distance over forward distance; a skater rides ~1.0.

const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")

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
	print("=== M37 slip gate tests ===")
	_test_slip_flags_skater()
	_test_low_slip_stays_credible()
	_test_ceiling_is_a_ratchet()
	await _test_rollout_exposes_slip_fields()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_slip_flags_skater() -> void:
	print("- a high slip_ratio flips an otherwise-credible gait to skate_or_spin")
	# Identical to the credible-walk fixture except slip_ratio is well over the ceiling.
	var skater := SimRolloutScript.classify_locomotion(4.0, 1.6, 0.85, 0.1, 0.9, 0.1, true,
			0.0, 0.5, 0.1, 0.2, 0.6, 1.2,
			SimRolloutScript.MAX_ASSIST_RATIO,
			SimRolloutScript.MAX_SLIP_RATIO + 0.5, SimRolloutScript.MAX_SLIP_RATIO)
	_check(not bool(skater["credible_walk"]), "skater is not a credible walk")
	_check(skater["reasons"].has("slip_or_skid"), "skater is flagged slip_or_skid")
	_check(skater["class"] == &"skate_or_spin", "skater classified as skate_or_spin")


func _test_low_slip_stays_credible() -> void:
	print("- a planted (low-slip) gait remains credible")
	var planted := SimRolloutScript.classify_locomotion(4.0, 1.6, 0.85, 0.1, 0.9, 0.1, true,
			0.0, 0.5, 0.1, 0.2, 0.6, 1.2,
			SimRolloutScript.MAX_ASSIST_RATIO,
			0.2, SimRolloutScript.MAX_SLIP_RATIO)
	_check(bool(planted["credible_walk"]), "low-slip planted gait is credible")
	_check(not planted["reasons"].has("slip_or_skid"), "no slip flag for a planted foot")


func _test_ceiling_is_a_ratchet() -> void:
	print("- a tightened ceiling can reject a gait the default would pass")
	var slip := SimRolloutScript.MAX_SLIP_RATIO * 0.8
	var loose := SimRolloutScript.classify_locomotion(4.0, 1.6, 0.85, 0.1, 0.9, 0.1, true,
			0.0, 0.5, 0.1, 0.2, 0.6, 1.2,
			SimRolloutScript.MAX_ASSIST_RATIO, slip, SimRolloutScript.MAX_SLIP_RATIO)
	var strict := SimRolloutScript.classify_locomotion(4.0, 1.6, 0.85, 0.1, 0.9, 0.1, true,
			0.0, 0.5, 0.1, 0.2, 0.6, 1.2,
			SimRolloutScript.MAX_ASSIST_RATIO, slip, slip - 0.01)
	_check(bool(loose["credible_walk"]), "default ceiling passes a moderate slip")
	_check(not bool(strict["credible_walk"]), "a tightened ceiling rejects the same slip")


func _test_rollout_exposes_slip_fields() -> void:
	print("- a measured rollout reports slip telemetry")
	var r: Dictionary = await SimRolloutScript.run(PartCatalog.make_quadruped(false), 2.0, 7, self)
	_check(r.has("mean_foot_slip") and r.has("slip_ratio") and r.has("slip_ratio_ceiling"),
			"rollout exposes slip fields")
	_check(float(r.get("mean_foot_slip", -1.0)) >= 0.0, "mean_foot_slip is non-negative")
	_check(is_finite(float(r.get("slip_ratio", INF))), "slip_ratio is finite")
