extends SceneTree

## M46 (capstone) — adversarial combat training loop. Two creatures fight in one isolated world,
## both scored from real contact impulse. A weaponed aggressor that charges + strikes beats a
## no-op opponent above chance, and the winner is held to the M38 anti-flail floor.

const AdversarialBoutScript := preload("res://scripts/sim/adversarial_bout.gd")

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
	print("=== M46 adversarial combat loop tests ===")
	await _test_adversarial_bout_runs()
	await _test_striker_beats_noop()
	await _test_curriculum_runs()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_adversarial_bout_runs() -> void:
	print("- two creatures fight in one isolated world and are both scored")
	var r: Dictionary = await AdversarialBoutScript.run_bout(
			PartCatalog.make_scorpion_v2(), PartCatalog.make_quadruped(false), self)
	print("  bout: dmg_to_a=%.2f dmg_to_b=%.2f winner=%s contacts=%d" % [
			float(r.get("damage_to_a", 0.0)), float(r.get("damage_to_b", 0.0)),
			String(r.get("winner", "?")), int(r.get("contacts", 0))])
	_check(bool(r.get("ok", false)), "bout completes with a finite sim")
	_check(r.has("a_score") and r.has("b_score") and r.has("winner"), "both combatants are scored")
	_check(is_equal_approx(float(r["a_score"]) + float(r["b_score"]), 0.0),
			"scoring is zero-sum (damage_dealt - damage_taken)")


func _test_striker_beats_noop() -> void:
	print("- a weaponed striker beats a no-op opponent above chance")
	var p := AdversarialBoutScript.BoutParams.new()
	p.a_strikes = true
	p.b_strikes = false
	var r: Dictionary = await AdversarialBoutScript.run_bout(
			PartCatalog.make_scorpion_v2(), PartCatalog.make_quadruped(false), self, p)
	print("  striker vs no-op: dmg_to_b=%.2f dmg_to_a=%.2f winner=%s a_floor_ok=%s" % [
			float(r.get("damage_to_b", 0.0)), float(r.get("damage_to_a", 0.0)),
			String(r.get("winner", "?")), str(r.get("a_floor_ok", false))])
	_check(float(r.get("damage_to_b", 0.0)) > 0.0, "the striker lands real impulse on the opponent")
	_check(r.get("winner", &"") == &"a" and float(r["a_score"]) > 0.0,
			"the striker wins (deals more than it takes)")
	_check(bool(r.get("a_floor_ok", false)),
			"the winner respects the M38 anti-flail floor (no teleport/explosion)")


func _test_curriculum_runs() -> void:
	print("- the fixed-opponent curriculum runs a champion against an opponent pool")
	var champ := PartCatalog.make_scorpion_v2()
	var pool := [PartCatalog.make_quadruped(false), PartCatalog.make_tortoise_v2()]
	var results: Array = await AdversarialBoutScript.run_curriculum(champ, pool, self)
	_check(results.size() == 2, "curriculum runs one bout per opponent")
	_check(bool(results[0].get("ok", false)) and bool(results[1].get("ok", false)),
			"every curriculum bout completes")
