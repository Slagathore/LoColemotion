extends SceneTree

## M48 — self-play combat training. BoutFitness scores a genome by physics bouts vs a fixed
## opponent pool (deterministic); selection (not noise) drives improvement (the E6 negative control).

const AdversarialTrainerScript := preload("res://scripts/sim/adversarial_trainer.gd")

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
	print("=== M48 adversarial trainer tests ===")
	_test_selection_beats_random()
	await _test_bout_fitness_signal()
	await _test_train_runs()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


# E6 negative control (pure, deterministic): selection picks better-than-random from a fitness
# gradient. If random selection matched tournament selection, "training" would be noise.
func _test_selection_beats_random() -> void:
	print("- selection out-picks random (the negative control)")
	var fits := PackedFloat32Array([0.0, 1.0, 2.0, 3.0, 4.0, 5.0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var sel_sum := 0.0
	var rnd_sum := 0.0
	var n := 200
	for _i in n:
		sel_sum += fits[AdversarialTrainerScript._tournament(fits, rng, 3)]
		rnd_sum += fits[rng.randi_range(0, fits.size() - 1)]
	print("  mean selected=%.3f  mean random=%.3f" % [sel_sum / n, rnd_sum / n])
	_check(sel_sum / n > rnd_sum / n + 0.5, "tournament selection beats random (selection matters)")


# E5: the combat fitness is a real, deterministic, SELECTABLE signal — it discriminates between
# different bodies (so selection has a gradient to climb) and repeats exactly for fixed inputs.
# (Whether a WEAPON lands is a skill the multi-generation training discovers — the un-trained
# morphology tackles with its body, per the M41 strike limitation; that's what training is for.)
func _test_bout_fitness_signal() -> void:
	print("- BoutFitness is a real, deterministic, discriminating signal")
	var fit := AdversarialTrainerScript.BoutFitness.new()
	fit.opponents = [PartCatalog.make_quadruped(false)]
	fit.horizon_s = 1.2
	var a := await fit.score(PartCatalog.make_scorpion_v2(), self)
	var b := await fit.score(PartCatalog.make_tortoise_v2(), self)
	print("  fitness scorpion=%.2f tortoise=%.2f" % [a, b])
	_check(is_finite(a) and is_finite(b) and absf(a - b) > 0.5,
			"combat fitness discriminates between different bodies (a selectable gradient)")
	var a2 := await fit.score(PartCatalog.make_scorpion_v2(), self)
	_check(is_equal_approx(a, a2), "combat fitness is deterministic for fixed pool+seed")


func _test_train_runs() -> void:
	print("- the generational self-play loop runs and returns a champion + history")
	var fit := AdversarialTrainerScript.BoutFitness.new()
	fit.opponents = [PartCatalog.make_quadruped(false)]
	fit.horizon_s = 1.0
	var result := await AdversarialTrainerScript.train(
			PartCatalog.make_scorpion_v2(), fit, self, 1, 3)
	_check(result.has("champion") and result["champion"] != null, "train returns a champion")
	_check((result["history"] as Array).size() == 1, "train records per-generation history")
	_check(float(result["champion_fit"]) > -INF, "champion has a real combat fitness")
