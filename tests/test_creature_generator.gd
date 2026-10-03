extends SceneTree

const CreatureGeneratorScript := preload("res://scripts/sim/creature_generator.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")
const CreatureBodyScript := preload("res://scripts/sim/creature_body.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== CreatureGenerator tests ===")
	_test_determinism_and_variation()
	_test_valid_evaluable_and_driven()
	_test_multi_segment_and_biped()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_determinism_and_variation() -> void:
	print("- same seed replays, different seed changes")
	var a_cfg := CreatureGeneratorScript.Config.new()
	a_cfg.seed = 123
	var b_cfg := CreatureGeneratorScript.Config.new()
	b_cfg.seed = 123
	var c_cfg := CreatureGeneratorScript.Config.new()
	c_cfg.seed = 124
	var a := CreatureGeneratorScript.generate(a_cfg)
	var b := CreatureGeneratorScript.generate(b_cfg)
	var c := CreatureGeneratorScript.generate(c_cfg)
	_check(EvolutionEngine.genome_signature(a) == EvolutionEngine.genome_signature(b), "same seed generates identical genome")
	_check(EvolutionEngine.genome_signature(a) != EvolutionEngine.genome_signature(c), "different seed changes generated genome")


func _test_valid_evaluable_and_driven() -> void:
	print("- generated bodies validate, evaluate, and bind every limb")
	var cfg := CreatureGeneratorScript.Config.new()
	cfg.seed = 777
	cfg.spine_segments_min = 2
	cfg.spine_segments_max = 2
	cfg.limb_pairs_min = 2
	cfg.limb_pairs_max = 2
	var root_gene := CreatureGeneratorScript.generate(cfg)
	var chk := GenomeSnapshot.validate_unique(root_gene)
	_check(bool(chk["ok"]), "generated genome passes uniqueness validation")
	var eval := CharacteristicsEvaluator.evaluate(root_gene)
	_check(bool(eval["status"]["ok"]) and is_finite(float(eval["total_mass"])), "generated genome evaluates with finite mass")
	var body: Node3D = CreatureBodyScript.build(root_gene, Transform3D.IDENTITY)
	root.add_child(body)
	var ctrl := CpgControllerScript.new()
	ctrl.bind(body, root_gene)
	root.add_child(ctrl)
	_check(ctrl.drive_count() == CreatureGeneratorScript.limb_count(root_gene), "every generated limb binds as a driven joint")
	body.queue_free()
	ctrl.queue_free()


func _test_multi_segment_and_biped() -> void:
	print("- multi-segment limbs and the biped body plan")
	var c1 := CreatureGeneratorScript.Config.new()
	c1.seed = 5
	c1.spine_segments_min = 1
	c1.spine_segments_max = 1
	c1.limb_pairs_min = 2
	c1.limb_pairs_max = 2
	c1.leg_segments = 1
	var c3 := CreatureGeneratorScript.Config.new()
	c3.seed = 5
	c3.spine_segments_min = 1
	c3.spine_segments_max = 1
	c3.limb_pairs_min = 2
	c3.limb_pairs_max = 2
	c3.leg_segments = 3
	var g1 := CreatureGeneratorScript.generate(c1)
	var g3 := CreatureGeneratorScript.generate(c3)
	_check(CreatureGeneratorScript.limb_count(g3) > CreatureGeneratorScript.limb_count(g1),
			"more leg segments -> more driven limb parts (knees)")
	_check(_min_locomotor_y(g3) * 2.0 < _max_locomotor_y(g3),
			"3-segment legs end in a smaller hinged foot link")
	_check(g3.gait != null and g3.gait.traction_scale > 0.0 and g3.gait.posture_scale > 0.0,
			"generated radial walkers carry tuned traction/posture gait scales")

	var bcfg := CreatureGeneratorScript.Config.new()
	bcfg.seed = 9
	bcfg.biped = true
	bcfg.leg_segments = 2
	bcfg.arm_pairs = 1
	bcfg.arm_segments = 2
	var biped := CreatureGeneratorScript.generate(bcfg)
	_check(bool(GenomeSnapshot.validate_unique(biped)["ok"]), "biped validates")
	_check(_count_tag(biped, &"ground_contact") == 2, "biped stands on exactly two feet")
	_check(biped.gait != null and biped.gait.traction_scale > 0.0 and biped.gait.posture_scale > 0.0,
			"biped carries tuned traction/posture gait scales")
	var body: Node3D = CreatureBodyScript.build(biped, Transform3D.IDENTITY)
	root.add_child(body)
	var ctrl := CpgControllerScript.new()
	ctrl.bind(body, biped)
	root.add_child(ctrl)
	_check(ctrl.drive_count() == CreatureGeneratorScript.limb_count(biped),
			"every biped limb segment binds as a driven joint")
	_check(ctrl.drive_count() >= 8, "biped drives two 2-segment legs and two 2-segment arms")
	body.queue_free()
	ctrl.queue_free()

	var hex := CreatureGeneratorScript.make_hexapod(11)
	_check(_count_tag(hex, &"ground_contact") == 6, "hexapod stands on six feet")
	_check(CreatureGeneratorScript.limb_count(hex) >= 6, "hexapod has more than four driven legs")


func _count_tag(root_gene: PartGene, tag: StringName) -> int:
	var fold := CharacteristicsEvaluator.fold_graph(root_gene, Transform3D.IDENTITY)
	var n := 0
	for p in fold["parts"]:
		if p.tags.has(tag):
			n += 1
	return n


func _min_locomotor_y(root_gene: PartGene) -> float:
	var best := INF
	for g in _walk(root_gene):
		if g.tags.has(&"locomotor") and g.definition != null:
			best = minf(best, g.definition.extents.y)
	return 0.0 if best == INF else best


func _max_locomotor_y(root_gene: PartGene) -> float:
	var best := 0.0
	for g in _walk(root_gene):
		if g.tags.has(&"locomotor") and g.definition != null:
			best = maxf(best, g.definition.extents.y)
	return best


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
