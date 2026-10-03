extends SceneTree

const GenScript := preload("res://scripts/sim/creature_generator.gd")
const OptScript := preload("res://scripts/sim/gait_optimizer.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== GaitOptimizer tests ===")
	await _test_optimize_improves_or_holds()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_optimize_improves_or_holds() -> void:
	print("- optimizer finds a phase per driven socket and never regresses fitness")
	var cfg := GenScript.Config.new()
	cfg.seed = 1
	cfg.leg_segments = 2
	var g := GenScript.generate(cfg)
	var sockets := OptScript.driven_sockets(g)
	_check(sockets.size() >= 4, "finds the driven leg sockets")

	var r = await OptScript.optimize(g, self, 8, 1.5, 1, 1)
	_check(r.phases.size() == sockets.size(), "optimized one phase per driven socket")
	_check(is_finite(r.fitness) and is_finite(r.forward), "optimized fitness/forward are finite")
	_check(r.frequency_scale >= 0.4 and r.frequency_scale <= 2.5, "frequency stays in range")
	_check(r.fitness >= r.baseline_fitness - 1e-6, "hill-climb never regresses below baseline")
	# gait-shape search space (2026-07-03): in range, or the 0 "derived default" sentinel
	_check(r.step_len == 0.0 or (r.step_len >= 0.05 and r.step_len <= 0.35),
			"step_len is sentinel or in range")
	_check(r.step_h == 0.0 or (r.step_h >= 0.02 and r.step_h <= 0.15),
			"step_h is sentinel or in range")
	_check(r.duty == 0.0 or (r.duty >= 0.5 and r.duty <= 0.9), "duty is sentinel or in range")
	_check(r.swing_kq_scale >= 0.4 and r.swing_kq_scale <= 2.5, "swing_kq_scale stays in range")
	_check(r.swing_kd_scale >= 0.4 and r.swing_kd_scale <= 2.5, "swing_kd_scale stays in range")

	# applying the tuned phases mutates the genome's gait
	OptScript.apply_to(g, r)
	for sid in r.phases:
		_check(absf(float(g.gait.assignments[sid]) - float(r.phases[sid])) < 1e-6,
				"apply_to writes tuned phase %s into the gait" % String(sid))
		break
	_check(absf(float(g.gait.swing_kq_scale) - r.swing_kq_scale) < 1e-6,
			"apply_to writes swing_kq_scale")
	if r.step_len > 0.0:
		_check(absf(float(g.gait.step_len) - r.step_len) < 1e-6, "apply_to writes step_len")

	# a 0-sentinel base ADOPTS an in-range value on perturb (never an additive step from 0
	# that would clamp to the range minimum — the degenerate-stride trap)
	var base = OptScript.Result.new()
	var prng := RandomNumberGenerator.new()
	prng.seed = 7
	var p = OptScript._perturb(base, prng, 0.3)
	_check(p.step_len >= 0.05 and p.step_len <= 0.35, "sentinel step_len adopts in-range value")
	_check(p.step_h >= 0.02 and p.step_h <= 0.15, "sentinel step_h adopts in-range value")
	_check(p.duty >= 0.5 and p.duty <= 0.9, "sentinel duty adopts in-range value")
