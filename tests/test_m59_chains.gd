extends SceneTree

## M59 — connectivity of the re-authored v2 side legs. The old `_v2_side_leg` fanned every segment
## off the body (disjoint stubs); the chain version parents upper->lower->ankle->foot so each
## segment meets the previous one's distal end (M47 proximal-end anchoring). This extends the M47
## fold-gap check per chain-fixed body: consecutive colinear segments sit a half-length apart, so
## center distance == (a.dims.y + b.dims.y) * 0.5 with no gap.

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== M59 chain connectivity tests ===")
	_test_chains()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_chains() -> void:
	_check_leg_chain(PartCatalog.make_spider_v2(), "spider_L0", "spider")
	_check_leg_chain(PartCatalog.make_spider_v2(), "spider_R3", "spider far-side")
	_check_leg_chain(PartCatalog.make_daddy_longlegs_v2(), "dll_L0", "daddy longlegs")
	_check_leg_chain(PartCatalog.make_scorpion_v2(), "scorp_L0", "scorpion")


func _check_leg_chain(root_gene: PartGene, prefix: String, label: String) -> void:
	var parts: Array = CE.fold_graph(root_gene, Transform3D.IDENTITY)["parts"]
	var up = _by_sock(parts, prefix + "_upper")
	var lo = _by_sock(parts, prefix + "_lower")
	var an = _by_sock(parts, prefix + "_ankle")
	var ft = _by_sock(parts, prefix + "_foot")
	if up == null or lo == null or an == null:
		_check(false, "%s: leg segments present (upper/lower/ankle)" % label)
		return
	_check_gap(up, lo, "%s upper->lower" % label)
	_check_gap(lo, an, "%s lower->ankle" % label)
	if ft != null:
		_check_gap(an, ft, "%s ankle->foot" % label)


func _check_gap(a, b, label: String) -> void:
	var want: float = (a.dims.y + b.dims.y) * 0.5
	var got: float = a.com_world.distance_to(b.com_world)
	_check(absf(got - want) < 0.06,
			"%s connected end-to-end (got %.3f, want %.3f)" % [label, got, want])


func _by_sock(parts: Array, sid: String):
	for p in parts:
		if p.socket != null and String(p.socket.id) == sid:
			return p
	return null
