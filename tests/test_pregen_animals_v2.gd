extends SceneTree

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Pregen animal v2 morphology tests ===")
	_test_v2_bestiary_shape_contracts()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_v2_bestiary_shape_contracts() -> void:
	var cards := {}
	for card in PartCatalog.built_in_cards():
		cards[card.display_name] = card.root

	var flagship: PartGene = cards["Built-in Quadruped"]
	_check(_count_tag(flagship, &"knee") >= 4 and _count_tag(flagship, &"ankle") >= 4
			and _count_tag(flagship, &"foot") == 4,
			"flagship quadruped is the segmented knee/ankle/foot successor")

	var urchin: PartGene = cards["Built-in Sea Urchin"]
	_check(_count_tag(urchin, &"spike") >= 20, "urchin has spikes over the central body")
	_check(_count_tag(urchin, &"pogo") >= 8 and _count_tag(urchin, &"ground_contact") >= 8,
			"urchin has radial pogo-capable ground spines")

	var serpent: PartGene = cards["Built-in Serpent"]
	_check(_span(serpent).z > 2.3, "serpent segments snake out instead of stacking")
	_check(_count_tag(serpent, &"serpent") >= 9 and _count_tag(serpent, &"foot") == 0,
			"serpent is a limbless segmented undulator")

	var centipede: PartGene = cards["Built-in Centipede"]
	_check(_span(centipede).z > 1.7, "centipede body segments extend in a chain")
	_check(_count_tag(centipede, &"centipede") >= 20 and _count_tag(centipede, &"ground_contact") >= 16,
			"centipede has many side legs along the body")

	var mantis: PartGene = cards["Built-in Mantis"]
	_check(_count_tag(mantis, &"blade") >= 2 and _count_tag(mantis, &"attack") >= 4,
			"mantis has bladed raptorial forearms")
	_check(_count_tag(mantis, &"foot") == 2, "mantis keeps two walking feet")

	var scorpion: PartGene = cards["Built-in Scorpion"]
	_check(_count_tag(scorpion, &"foot") == 8, "scorpion has eight side walking legs")
	_check(_count_tag(scorpion, &"actuated") >= 5 and _count_tag(scorpion, &"stinger") == 1,
			"scorpion has a multi-segment actuated strike tail")

	var frog: PartGene = cards["Built-in Frog"]
	_check(_count_tag(frog, &"hindlimb") >= 8 and _count_tag(frog, &"spring") >= 8,
			"frog has spring-tagged segmented hind legs")
	_check(_count_tag(frog, &"foot") == 4, "frog has two big rear feet and two small front feet")

	var spider: PartGene = cards["Built-in Spider"]
	_check(_count_tag(spider, &"foot") == 8, "spider has eight feet")
	_check(_count_tag(spider, &"knee") >= 8 and _count_tag(spider, &"ankle") >= 8,
			"spider legs are multi-segmented")
	_check(_span(spider).x > 1.3, "spider legs emerge from the sides")

	var dll: PartGene = cards["Built-in Daddy Longlegs"]
	_check(_count_tag(dll, &"foot") == 8, "daddy longlegs has eight feet")
	_check(_span(dll).x > 1.45 and _count_tag(dll, &"knee") >= 8,
			"daddy longlegs has long segmented side legs")


func _count_tag(root_gene: PartGene, tag: StringName) -> int:
	var n := 0
	for g in _walk(root_gene):
		if g.tags.has(tag):
			n += 1
	return n


func _span(root_gene: PartGene) -> Vector3:
	var fold := CE.fold_graph(root_gene, Transform3D.IDENTITY)
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)
	for p in fold["parts"]:
		min_v.x = minf(min_v.x, p.com_world.x)
		min_v.y = minf(min_v.y, p.com_world.y)
		min_v.z = minf(min_v.z, p.com_world.z)
		max_v.x = maxf(max_v.x, p.com_world.x)
		max_v.y = maxf(max_v.y, p.com_world.y)
		max_v.z = maxf(max_v.z, p.com_world.z)
	return max_v - min_v


func _walk(root_gene: PartGene) -> Array[PartGene]:
	var out: Array[PartGene] = []
	_walk_into(root_gene, out)
	return out


func _walk_into(g: PartGene, out: Array[PartGene]) -> void:
	if g == null:
		return
	out.append(g)
	for child in g.children:
		_walk_into(child, out)
