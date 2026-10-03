extends SceneTree

## GaitPlanner — the foot-trajectory PLAN. Proves the coordination the sinusoid CPG could never
## hold: the planted foot stays at GROUND level through the whole power stroke (so it keeps contact
## and can propel), the swing foot lifts in a continuous arc, and the trajectory never jumps. This
## is the reference the honest tracker pulls the real foot toward.

const GaitPlannerScript := preload("res://scripts/sim/gait_planner.gd")

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
	print("=== GaitPlanner tests ===")
	_test_stance_grounded_swing_lifts()
	_test_trajectory_continuous()
	_test_stance_sweeps_backward()
	_test_trot_phasing()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


# frequency=1, offset=0 ⇒ phase == t, so t directly indexes the stride cycle.
func _one_leg(rest := Vector3(0.3, 0.05, 0.2)):
	var gp = GaitPlannerScript.new()
	gp.configure(1.0, 0.22, 0.07, 0.6)
	gp.add_leg(9, rest, 0.0)
	return gp


# Stance foot never lifts off the rest (ground) height; swing foot lifts, peaking mid-swing.
func _test_stance_grounded_swing_lifts() -> void:
	print("- stance stays grounded, swing lifts (peak mid-swing)")
	var gp = _one_leg()
	var rest_y := 0.05
	var stance_flat := true
	for i in 12:                                   # sample the stance window [0, duty)
		var t: float = (float(i) / 12.0) * float(gp.duty)
		if absf(float(gp.foot_target_local(0, t).y) - rest_y) > 1.0e-6:
			stance_flat = false
	_check(stance_flat, "stance foot held at ground height (no lift during power stroke)")
	# Mid-swing (halfway through [duty,1)) is the arc peak.
	var mid: float = float(gp.duty) + 0.5 * (1.0 - float(gp.duty))
	var peak: float = float(gp.foot_target_local(0, mid).y)
	_check(absf(peak - (rest_y + gp.step_height)) < 1.0e-6,
			"swing arc peaks at rest + step_height (%.3f)" % gp.step_height)
	# The foot never dips below the ground rest height anywhere in the cycle.
	var never_below := true
	for i in 100:
		if gp.foot_target_local(0, float(i) / 100.0).y < rest_y - 1.0e-6:
			never_below = false
	_check(never_below, "foot target never dips below ground rest height")


# The target is continuous across the stance→swing seam and across the cycle wrap (no teleport).
func _test_trajectory_continuous() -> void:
	print("- trajectory continuous at the stance/swing seam and the wrap")
	var gp = _one_leg()
	var eps := 1.0e-4
	var seam_a := gp.foot_target_local(0, gp.duty - eps)
	var seam_b := gp.foot_target_local(0, gp.duty + eps)
	_check(seam_a.distance_to(seam_b) < 5.0e-3, "continuous at stance→swing seam")
	var wrap_a := gp.foot_target_local(0, 1.0 - eps)
	var wrap_b := gp.foot_target_local(0, 0.0)
	_check(wrap_a.distance_to(wrap_b) < 5.0e-3, "continuous across the cycle wrap")


# During stance the planted foot moves backward in body frame (forward is -Z, so its z increases).
func _test_stance_sweeps_backward() -> void:
	print("- stance foot sweeps backward in body frame (the propulsive drag)")
	var gp = _one_leg()
	var z_start := gp.foot_target_local(0, 0.0).z            # start of stance (ahead)
	var z_end := gp.foot_target_local(0, gp.duty * 0.99).z   # end of stance (behind)
	_check(z_end > z_start, "planted foot travels backward (+Z) across stance")
	_check(absf((z_end - z_start) - gp.step_length) < 0.02,
			"stance travel ≈ step_length (%.2f m)" % gp.step_length)


# A trot: two legs a half-cycle apart are in opposite phases — one plants while the other swings.
func _test_trot_phasing() -> void:
	print("- trot diagonal pairs are a half-cycle out of phase")
	var gp = GaitPlannerScript.new()
	gp.configure(1.0, 0.22, 0.07, 0.6)
	gp.add_leg(9, Vector3(0.3, 0.05, 0.2), 0.0)     # leg A
	gp.add_leg(10, Vector3(-0.3, 0.05, 0.2), 0.5)   # leg B, diagonal partner
	# At t where A is early-stance, B (offset 0.5) is in swing.
	var t := 0.15
	_check(gp.is_stance(0, t) and not gp.is_stance(1, t),
			"at t=0.15 leg A plants while leg B swings")
	# Half a cycle later the roles flip.
	var t2 := 0.65
	_check(not gp.is_stance(0, t2) and gp.is_stance(1, t2),
			"at t=0.65 the roles flip (A swings, B plants)")
