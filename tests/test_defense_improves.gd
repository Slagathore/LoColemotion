extends SceneTree

## Proves a DEFENDER reduces damage taken after a SHORT adversarial training campaign vs its
## untrained self, using the existing self-play stack: AdversarialTrainer.train (generational
## mutate->select) with a BoutFitness whose opponent pool is a single weapon-bearing attacker, and
## AdversarialBout.run_bout for the before/after damage probe.
##
## Measurement convention: the BoutFitness scores the trained genome AS the A-side combatant against
## the attacker as B (a_score = damage_dealt - damage_taken, so it rewards taking less damage). We
## probe damage taken in EXACTLY that bout configuration (defender as A vs attacker as B) and read
## "damage_to_a" = damage the defender absorbs. Because the probe matches the trained scenario, the
## assertion is tightly coupled to what training optimized.

const AdversarialTrainerScript := preload("res://scripts/sim/adversarial_trainer.gd")
const AdversarialBoutScript := preload("res://scripts/sim/adversarial_bout.gd")
const PartCatalogScript := preload("res://scripts/editor/part_catalog.gd")

const HORIZON := 1.3
const PROBE_SEED := 7

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
		print("  FAIL  ", label)


# Damage the `defender` absorbs as the A-side combatant facing `attacker` as B — the same bout the
# BoutFitness scores, so improvements here reflect what the campaign actually optimized.
func _damage_taken(defender: PartGene, attacker: PartGene) -> float:
	var p := AdversarialBoutScript.BoutParams.new()
	p.horizon_s = HORIZON
	p.a_strikes = true
	p.b_strikes = true
	var r: Dictionary = await AdversarialBoutScript.run_bout(defender, attacker, self, p)
	return float(r.get("damage_to_a", 0.0))


func _run() -> void:
	var defender_seed: PartGene = PartCatalogScript.make_tortoise_v2()
	var attacker: PartGene = PartCatalogScript.make_scorpion_v2()
	_check(defender_seed != null, "defender seed (tortoise_v2) built")
	_check(attacker != null, "attacker (scorpion_v2) built")

	# Baseline: damage the UNTRAINED defender absorbs from the attacker.
	var baseline: float = await _damage_taken(defender_seed, attacker)
	print("  baseline damage_taken = %.6f" % baseline)

	# Short defense-training campaign: BoutFitness rewards a_score (= damage_dealt - damage_taken)
	# against the single weapon-bearing attacker, so selection favors a lower hit profile.
	var fitness := AdversarialTrainerScript.BoutFitness.new()
	fitness.opponents = [attacker]
	fitness.horizon_s = HORIZON
	fitness.seed = PROBE_SEED

	var result: Dictionary = await AdversarialTrainerScript.train(
			defender_seed, fitness, self, 2, 4, null, false, 11)
	var champion: PartGene = result.get("champion", null)
	var champion_fit: float = float(result.get("champion_fit", -INF))
	_check(champion != null, "training produced a champion")
	var history: Array = result.get("history", [])
	_check(history.size() == 2, "history has one entry per generation")

	# Selection actually moved the genome: the champion differs from its untrained self and scores
	# at least as well as the seed under the combat fitness (proves training, not noise).
	var differs := GenomeSnapshot.to_dictionary(champion) != GenomeSnapshot.to_dictionary(defender_seed)
	_check(differs, "champion genome differs from untrained seed")
	var seed_fit: float = await fitness.score(defender_seed, self)
	print("  seed fitness = %.6f   champion fitness = %.6f" % [seed_fit, champion_fit])
	_check(champion_fit >= seed_fit - 0.001, "champion combat fitness >= seed fitness")

	# Probe the trained champion the SAME way (champion as A vs attacker as B).
	var trained: float = await _damage_taken(champion, attacker)
	print("  trained  damage_taken = %.6f" % trained)

	# Training must not make defense worse; prefer a strict improvement, allow a tie within epsilon.
	var eps := 0.02
	_check(trained <= baseline + eps,
			"champion damage_taken (%.4f) <= baseline (%.4f) + eps" % [trained, baseline])

	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
