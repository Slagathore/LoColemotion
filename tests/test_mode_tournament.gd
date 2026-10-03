extends SceneTree

## M42 — generator affordances + multi-mode search. Affordances are derived from a body's
## structure; the tournament runs a rollout per plausible mode and picks the best from
## behaviour (a hopper selects hop, a radial urchin selects pogo). The assist-annealing
## curriculum only ever tightens (ratchet).

const ModeTournamentScript := preload("res://scripts/sim/mode_tournament.gd")
const CreatureAffordancesScript := preload("res://scripts/sim/creature_affordances.gd")

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
	print("=== M42 affordances + multi-mode tournament tests ===")
	_test_affordances_derived()
	_test_assist_anneal_ratchets()
	await _test_multi_mode_tournament()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_affordances_derived() -> void:
	print("- affordances are derived from body structure")
	var hopper := CreatureAffordancesScript.affordances(PartCatalog.make_hopper_v2())
	_check(bool(hopper["spring_leg"]), "hopper affords a spring leg")
	var urchin := CreatureAffordancesScript.affordances(PartCatalog.make_sea_urchin_v2())
	_check(bool(urchin["radial_spike"]), "urchin affords a radial spike array")
	var serpent := CreatureAffordancesScript.affordances(PartCatalog.make_serpent_v2())
	_check(bool(serpent["anisotropic_ventral"]) and bool(serpent["segmented_chain"]),
			"serpent affords an anisotropic segmented chain")
	var hop_modes := CreatureAffordancesScript.plausible_modes(PartCatalog.make_hopper_v2())
	var urchin_modes := CreatureAffordancesScript.plausible_modes(PartCatalog.make_sea_urchin_v2())
	_check(hop_modes.has(&"hop") and not hop_modes.has(&"pogo"), "hopper proposes hop, not pogo")
	_check(urchin_modes.has(&"pogo") and not urchin_modes.has(&"hop"), "urchin proposes pogo, not hop")


func _test_assist_anneal_ratchets() -> void:
	print("- assist annealing only ever tightens across generations")
	var generations := 8
	var prev := INF
	var monotone := true
	for g in generations:
		var s := ModeTournamentScript.anneal_assist(1.5, g, generations, 0.0)
		if s > prev + 1e-6:
			monotone = false
		prev = s
	_check(monotone, "assist scale never increases generation-to-generation")
	_check(is_equal_approx(ModeTournamentScript.anneal_assist(1.5, 0, generations), 1.5),
			"generation 0 keeps the base assist")
	_check(ModeTournamentScript.anneal_assist(1.5, generations - 1, generations) <= 0.01,
			"final generation anneals assist to ~the floor")
	_check(ModeTournamentScript.anneal_assist(1.5, 4, generations, 0.5) >= 0.5,
			"the floor is respected")


func _test_multi_mode_tournament() -> void:
	print("- the tournament selects the mode each body actually affords")
	var hop := await ModeTournamentScript.run(PartCatalog.make_hopper_v2(), self, 2.5, 7)
	print("  hopper best=%s results=%s" % [String(hop["best_mode"]), str(hop["results"])])
	_check(hop["best_mode"] == &"hop", "hopper body selects hop")
	var urchin := await ModeTournamentScript.run(PartCatalog.make_sea_urchin_v2(), self, 2.5, 7)
	print("  urchin best=%s results=%s" % [String(urchin["best_mode"]), str(urchin["results"])])
	_check(urchin["best_mode"] == &"pogo", "radial urchin body selects pogo")
