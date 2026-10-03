extends SceneTree

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")
const GenomeMutatorScript := preload("res://scripts/sim/genome_mutator.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== GenomeMutator tests ===")
	_test_seed_determinism()
	_test_validity_and_clamps()
	_test_crossover_validity()
	_test_evaluator_fuzz()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


func _cfg():
	var c = GenomeMutatorScript.Config.new()
	c.param_rate = 1.0
	c.topology_rate = 0.45
	c.gait_rate = 1.0
	return c


func _sig(root: PartGene) -> String:
	var out: Array[String] = []
	_sig_gene(root, out)
	return "|".join(out)


func _sig_gene(g: PartGene, out: Array[String]) -> void:
	if g == null:
		out.append("null")
		return
	var def_sig := "nodef"
	if g.definition != null:
		def_sig = "%s,%.6f,%s,%s" % [String(g.definition.part_type), g.definition.density,
				str(g.definition.extents), str(g.definition.centroid_offset)]
	var socket_sig := "nosocket"
	if g.socket != null:
		socket_sig = "%s,%s,%s,%s" % [String(g.socket.id), str(g.socket.parent_attachment),
				str(g.socket.child_anchor), str(g.socket.hinge_axis)]
	var joint_sig := "nojoint"
	if g.joint != null:
		joint_sig = "%.6f,%.6f,%.6f,%.6f" % [g.joint.amplitude, g.joint.rest_angle,
				g.joint.angle_min, g.joint.angle_max]
	var gait_sig := "nogait"
	if g.gait != null:
		var parts: Array[String] = []
		for key in g.gait.assignments.keys():
			parts.append("%s=%.6f" % [String(key), float(g.gait.assignments[key])])
		parts.sort()
		gait_sig = "%s:%s" % [String(g.gait.pattern), ",".join(parts)]
	out.append("%s;%s;%s;%s;%s;%s;%d" % [def_sig, socket_sig, joint_sig, gait_sig,
			str(g.scale), String(g.part_id), g.children.size()])
	for child in g.children:
		_sig_gene(child, out)


func _test_seed_determinism() -> void:
	print("- same seed gives identical offspring; different seed differs")
	var parent := PartCatalog.make_quadruped(false)
	var c = _cfg()
	var a: PartGene = GenomeMutatorScript.mutate(parent, c, _rng(1234))
	var b: PartGene = GenomeMutatorScript.mutate(parent, c, _rng(1234))
	var d: PartGene = GenomeMutatorScript.mutate(parent, c, _rng(4321))
	_check(_sig(a) == _sig(b), "same seed -> identical mutant signature")
	_check(_sig(a) != _sig(d), "different seed -> different mutant signature")
	_check(_sig(parent) != _sig(a), "mutant differs from parent")


func _test_validity_and_clamps() -> void:
	print("- mutants validate and clamps hold")
	var parent := PartCatalog.make_quadruped(false)
	var c = _cfg()
	var ok := true
	for i in 200:
		var child: PartGene = GenomeMutatorScript.mutate(parent, c, _rng(9000 + i))
		ok = ok and bool(GenomeSnapshot.validate_unique(child)["ok"])
		ok = ok and _clamps_hold(child)
	_check(ok, "200 mutants validate with scale/RoM/phase clamps")


func _test_crossover_validity() -> void:
	print("- crossover returns a valid isolated tree")
	var a := PartCatalog.make_quadruped(false)
	var b := PartCatalog.make_quadruped(true)
	var c = _cfg()
	c.crossover_rate = 1.0
	var child: PartGene = GenomeMutatorScript.crossover(a, b, c, _rng(77))
	_check(child != null and child != a, "crossover returns a new root")
	_check(bool(GenomeSnapshot.validate_unique(child)["ok"]), "crossover output validates")
	_check(_clamps_hold(child), "crossover output respects clamps")


func _test_evaluator_fuzz() -> void:
	print("- evaluator fuzzes through random mutants")
	var parent := PartCatalog.make_quadruped(false)
	var c = _cfg()
	var ok := true
	for i in 250:
		var child: PartGene = GenomeMutatorScript.mutate(parent, c, _rng(12000 + i))
		var r := CE.evaluate(child)
		ok = ok and bool(r["status"]["ok"])
		ok = ok and is_finite(float(r["total_mass"]))
		ok = ok and is_finite(float(r["probe"]["distance"]))
	_check(ok, "250 random mutants evaluate with no NaN/no crash")


func _clamps_hold(root: PartGene) -> bool:
	if root == null:
		return false
	var stack: Array[PartGene] = [root]
	while not stack.is_empty():
		var g: PartGene = stack.pop_back()
		if g.scale.x <= 0.0 or g.scale.y <= 0.0 or g.scale.z <= 0.0:
			return false
		if g.joint != null:
			if g.joint.angle_max < g.joint.angle_min:
				return false
		if g.gait != null:
			for key in g.gait.assignments.keys():
				var phase := float(g.gait.assignments[key])
				if phase < 0.0 or phase >= 1.0:
					return false
		for child in g.children:
			stack.append(child)
	return true
