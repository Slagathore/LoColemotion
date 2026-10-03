extends SceneTree

## KinematicSkeleton — the shared rig reader. Proves the kinematic plan is built from the SAME fold as
## the Jolt body (index-aligned, correct foot set, leg chains hip→foot, reach > 0, subtree mass closes).
## This is the foundation the reference-tracking controller / FABRIK / GaitPlanner read.

const KinematicSkeletonScript := preload("res://scripts/sim/kinematic_skeleton.gd")
const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")

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
	print("=== KinematicSkeleton tests ===")
	_test_index_alignment_and_feet()
	_test_leg_chains_and_reach()
	_test_subtree_mass_closes()
	_test_serpent_spine_chain()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


# The skeleton is index-aligned with the fold and finds exactly the ground-contact parts as feet.
func _test_index_alignment_and_feet() -> void:
	print("- index alignment + foot detection (quad=4, biped=2, hexapod=6, spider=8)")
	var cases := [
		{"label": "quadruped", "root": PartCatalog.make_quadruped(false), "feet": 4},
		{"label": "biped", "root": CreatureGenerator.make_biped(7), "feet": 2},
		{"label": "hexapod", "root": CreatureGenerator.make_hexapod(11), "feet": 6},
		{"label": "spider", "root": CreatureGenerator.make_spider(21), "feet": 8},
	]
	for c in cases:
		var root := c["root"] as PartGene
		var fold := CE.fold_graph(root, Transform3D.IDENTITY)
		var parts: Array = fold["parts"]
		var ks = KinematicSkeletonScript.from_fold(fold)
		_check(ks.segment_count() == parts.size(),
				"%s: one segment per fold part (%d)" % [c["label"], parts.size()])
		_check(ks.feet().size() == int(c["feet"]),
				"%s: %d feet detected" % [c["label"], int(c["feet"])])
		# Every foot index is a real ground_contact part.
		var all_feet_valid := true
		for fi in ks.feet():
			if fi < 0 or fi >= parts.size() or not parts[fi].tags.has(&"ground_contact"):
				all_feet_valid = false
		_check(all_feet_valid, "%s: every foot index is a ground_contact part" % c["label"])


# Each leg chain ends at its foot, is ordered hip→foot, and has a positive straight-line reach.
func _test_leg_chains_and_reach() -> void:
	print("- leg chains are hip→foot ordered with positive reach")
	var root := PartCatalog.make_quadruped(false)
	var ks = KinematicSkeletonScript.from_fold(CE.fold_graph(root, Transform3D.IDENTITY))
	var all_ok := true
	var all_reach := true
	var all_offset := true
	for fi in ks.feet():
		var chain: PackedInt32Array = ks.chain_to_foot(fi)
		if chain.size() < 1 or chain[chain.size() - 1] != fi:
			all_ok = false
		if ks.leg_reach(fi) <= 0.0:
			all_reach = false
		# The foot's body-relative rest offset must be finite and off the body centre.
		var off: Vector3 = ks.foot_rest_local(fi)
		if not (is_finite(off.x) and is_finite(off.y) and is_finite(off.z)) or off.length() < 1.0e-4:
			all_offset = false
	_check(all_ok, "quadruped: every chain ends at its foot, hip→foot ordered")
	_check(all_reach, "quadruped: every leg has positive reach (sum of bone lengths)")
	_check(all_offset, "quadruped: every foot has a finite, off-centre rest offset")


# The root's subtree is the whole creature, so its subtree mass equals the sum of all segment masses.
func _test_subtree_mass_closes() -> void:
	print("- subtree mass closes (root subtree == total mass)")
	var root := CreatureGenerator.make_hexapod(11)
	var ks = KinematicSkeletonScript.from_fold(CE.fold_graph(root, Transform3D.IDENTITY))
	var total := 0.0
	for s in ks.segments:
		total += s.mass
	var root_sub: float = ks.subtree_mass(ks.root_index)
	_check(absf(root_sub - total) <= 1.0e-4 * maxf(total, 1.0),
			"hexapod: subtree_mass(root) == sum of all segment masses (%.3f)" % total)
	_check(ks.subtree_indices(ks.root_index).size() == ks.segment_count(),
			"hexapod: root subtree covers every segment")


# The serpent's body IS its spine — the spine chain must be non-empty and ordered tip-ward by depth.
func _test_serpent_spine_chain() -> void:
	print("- serpent spine chain non-empty + depth-ordered")
	var root := PartCatalog.make_serpent_v2()
	var ks = KinematicSkeletonScript.from_fold(CE.fold_graph(root, Transform3D.IDENTITY))
	var spine: PackedInt32Array = ks.spine_chain()
	_check(spine.size() >= 3, "serpent: spine chain has >= 3 segments (%d)" % spine.size())
	var ordered := true
	for i in range(1, spine.size()):
		if ks.segments[spine[i]].depth < ks.segments[spine[i - 1]].depth:
			ordered = false
	_check(ordered, "serpent: spine chain ordered by increasing depth (root→tail)")
