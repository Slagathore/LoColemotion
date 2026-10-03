extends SceneTree

## The fun layer — 10 deterministic flavor helpers. Pure functions, so easy to pin.

const CreatureFlavorScript := preload("res://scripts/sim/creature_flavor.gd")

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
	print("=== Creature flavor tests ===")
	var quad := PartCatalog.make_quadruped(false)
	var scorpion := PartCatalog.make_scorpion_v2()
	var urchin := PartCatalog.make_sea_urchin_v2()
	var serpent := PartCatalog.make_serpent_v2()

	# 1. name_for is deterministic and non-empty.
	_check(CreatureFlavorScript.name_for(quad) == CreatureFlavorScript.name_for(quad)
			and CreatureFlavorScript.name_for(quad).length() > 0, "name_for is deterministic")
	# 2. taxonomy reflects affordances.
	_check(CreatureFlavorScript.taxonomy(urchin).begins_with("Echinoides"), "urchin taxonomy is Echinoides")
	_check(CreatureFlavorScript.taxonomy(serpent).begins_with("Serpentis"), "serpent taxonomy is Serpentis")
	# 3. temperament: a weaponed scorpion is aggressive; a plain quad is not.
	_check(CreatureFlavorScript.temperament(scorpion) in ["Aggressive", "Battle-hardened"],
			"scorpion temperament is combative")
	_check(CreatureFlavorScript.temperament(quad) != "Aggressive", "plain quadruped is not aggressive")
	# 4. dna_signature is a stable 3-glyph string.
	_check(CreatureFlavorScript.dna_signature(quad) == CreatureFlavorScript.dna_signature(quad),
			"dna_signature is deterministic")
	# 5. efficiency medals tier by CoT.
	_check(CreatureFlavorScript.efficiency_medal(0.1).contains("Gold"), "low CoT -> gold")
	_check(CreatureFlavorScript.efficiency_medal(5.0).contains("Participation"), "high CoT -> participation")
	# 6. locomotion flavor labels every class.
	_check(CreatureFlavorScript.locomotion_flavor(&"fall_or_tip").contains("Faceplant"),
			"fall_or_tip gets a funny label")
	# 7. threat: scorpion (weapons) out-rates the quad.
	var st := int(CreatureFlavorScript.threat_level(scorpion)["stars"])
	var qt := int(CreatureFlavorScript.threat_level(quad)["stars"])
	_check(st > qt, "weaponed scorpion is more threatening than a plain quad")
	# 8. gait rhythm renders per-socket strips.
	_check(CreatureFlavorScript.gait_rhythm(quad).contains("▮"), "gait rhythm renders a beat strip")
	# 9. combat quip reacts to the score.
	_check(CreatureFlavorScript.combat_quip("A", "B", 74.0, 2.0).contains("demolished"),
			"a lopsided bout gets a demolition quip")
	# 10. stat card is a multi-line console card.
	var card := CreatureFlavorScript.stat_card(scorpion, {"cost_of_transport": 0.1,
			"locomotion_class": &"credible_walk"})
	_check(card.contains("Threat") and card.contains("Economy") and card.split("\n").size() >= 5,
			"stat card assembles name + taxonomy + threat + medal")

	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
