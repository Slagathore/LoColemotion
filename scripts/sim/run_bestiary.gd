extends SceneTree

## Fun console tool: print a flavor "stat card" for every built-in creature.
## Run: godot --headless --path . --script res://scripts/sim/run_bestiary.gd

const CreatureFlavorScript := preload("res://scripts/sim/creature_flavor.gd")


func _initialize() -> void:
	print("\n=== SPORESPORE BESTIARY ===\n")
	for card in PartCatalog.built_in_cards():
		print(CreatureFlavorScript.stat_card(card.root))
		print("")
	quit(0)
