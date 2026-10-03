extends SceneTree

## Morphogenesis v1 — exercises Morphogen.grow():
##   (a) a grown creature has >= 5 parts;
##   (b) it is folds-connected — a parent/child spine segment pair sits exactly
##       (dims.y sum) * 0.5 apart (mirrors test_m59_chains.gd's M47 gap check);
##   (c) determinism — grow(7) twice gives the same part_count and root part_type;
##   (d) two different seeds give a different part_count OR structural signature.

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")
const Morphogen := preload("res://scripts/sim/morphogen.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Morphogen v1 tests ===")
	_test_part_count()
	_test_connected()
	_test_determinism()
	_test_seeds_differ()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


# (a) non-degenerate body of at least 5 parts.
func _test_part_count() -> void:
	for seed in [1, 7, 8, 42, 100]:
		var root := Morphogen.grow(seed)
		_check(root != null, "grow(%d) returns a tree" % seed)
		var n := _count(root)
		_check(n >= 5, "grow(%d) has >= 5 parts (got %d)" % [seed, n])


# (b) consecutive spine segments meet end-to-end (no gap), per M47 proximal anchoring.
func _test_connected() -> void:
	var root := Morphogen.grow(7)
	var parts: Array = CE.fold_graph(root, Transform3D.IDENTITY)["parts"]
	# The first grown spine segment parents off the root; assert root -> seg_1 gap.
	var seg1 = _by_id(parts, "morpho_seg_1")
	var root_part = _root_part(parts)
	_check(root_part != null and seg1 != null,
			"root + first spine segment present in fold graph")
	if root_part != null and seg1 != null:
		_check_gap(root_part, seg1, "root -> morpho_seg_1")
	# If the spine grew further, assert seg_1 -> seg_2 too.
	var seg2 = _by_id(parts, "morpho_seg_2")
	if seg1 != null and seg2 != null:
		_check_gap(seg1, seg2, "morpho_seg_1 -> morpho_seg_2")


# (c) determinism: same seed -> identical structure.
func _test_determinism() -> void:
	var a := Morphogen.grow(7)
	var b := Morphogen.grow(7)
	_check(_count(a) == _count(b),
			"grow(7) twice => same part_count (%d == %d)" % [_count(a), _count(b)])
	_check(a.definition.part_type == b.definition.part_type,
			"grow(7) twice => same root part_type (%s)" % [a.definition.part_type])
	_check(_signature(a) == _signature(b),
			"grow(7) twice => identical structural signature")


# (d) different seeds give a different body (count OR signature).
func _test_seeds_differ() -> void:
	var a := Morphogen.grow(7)
	var b := Morphogen.grow(8)
	var differs := _count(a) != _count(b) or _signature(a) != _signature(b)
	_check(differs, "grow(7) != grow(8) in part_count or signature (%d vs %d)"
			% [_count(a), _count(b)])


# --- helpers ----------------------------------------------------------------

func _check_gap(a, b, label: String) -> void:
	var want: float = (a.dims.y + b.dims.y) * 0.5
	var got: float = a.com_world.distance_to(b.com_world)
	_check(absf(got - want) < 0.06,
			"%s connected end-to-end (got %.3f, want %.3f)" % [label, got, want])


func _by_id(parts: Array, pid: String):
	for p in parts:
		if String(p.part_id) == pid:
			return p
	return null


func _root_part(parts: Array):
	# FoldPart.parent is an int index (-1 for root), not an object.
	for p in parts:
		if p.parent < 0:
			return p
	return null


# Stable structural fingerprint: part_id + part_type + rounded dims, in fold order.
func _signature(root: PartGene) -> String:
	var parts: Array = CE.fold_graph(root, Transform3D.IDENTITY)["parts"]
	var sig := ""
	for p in parts:
		sig += "%s:%s:%.2f,%.2f,%.2f|" % [
			p.part_id, root.definition.part_type if p.parent < 0 else "",
			p.dims.x, p.dims.y, p.dims.z]
	return sig


func _count(root: PartGene) -> int:
	if root == null:
		return 0
	var n := 1
	for ch in root.children:
		n += _count(ch)
	return n
