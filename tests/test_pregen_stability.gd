extends SceneTree

## M59 — pregen physical stability. A creature whose body segments were FANNED off a distant root
## (serpent/centipede) jointed each segment across meters of empty space; the solver could not hold
## it and the body exploded (non-finite / teleport) after a few seconds. After re-authoring those
## bodies into neighbour-jointed CHAINS, a multi-second rollout must stay finite and not teleport.

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
	print("=== M59 pregen stability tests ===")
	await _stable("serpent", PartCatalog.make_serpent_v2())
	await _stable("centipede", PartCatalog.make_centipede_v2())
	var nodrive := PartCatalog.make_centipede_v2()
	nodrive.gait = null
	await _stable("centipede(no-drive)", nodrive)
	await _stable("spider", PartCatalog.make_spider_v2())
	await _stable("scorpion", PartCatalog.make_scorpion_v2())
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _stable(label: String, root_gene: PartGene) -> void:
	# 4s is well past the "few seconds" where the fanned bodies blew up.
	var m = await SimRollout.run(root_gene, 4.0, 7, self)
	var ok := bool(m.get("ok", false))
	var teleport := bool(m.get("teleport", false))
	var step := float(m.get("max_com_step", 0.0))
	print("  %s ok=%s teleport=%s max_com_step=%.3f" % [label, str(ok), str(teleport), step])
	_check(ok, "%s rollout stays finite (no explosion)" % label)
	_check(not teleport, "%s does not teleport (no solver blow-up)" % label)
