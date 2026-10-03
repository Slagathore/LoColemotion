class_name CreatureFeatures
extends RefCounted

## Semantic body descriptor for cross-creature gait transfer. The idea (per the
## design goal): a new 6-legged creature with knees should warm-start from
## whatever a *similar* knee'd body learned, even if leg counts differ. So
## distance() weights STRUCTURAL traits (has-knees, biped, leg count) far more
## than raw size, and continuous traits are normalized.

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")


static func extract(root_gene: PartGene) -> Dictionary:
	var fold := CE.fold_graph(root_gene, Transform3D.IDENTITY)
	var parts: Array = fold["parts"]
	var legs := 0
	var feet := 0
	var spine := 0
	var max_chain := 1
	var min_y := INF
	var max_y := -INF
	var max_abs_x := 0.0
	for p in parts:
		if p.tags.has(&"ground_contact"):
			feet += 1
		if p.tags.has(&"spine"):
			spine += 1
		if p.tags.has(&"locomotor") and p.socket != null and p.hinge_axis.length() > CE.EPS:
			legs += 1
			max_chain = maxi(max_chain, _chain_depth(parts, int(p.index)))
		var aabb: AABB = p.world_aabb
		min_y = minf(min_y, aabb.position.y)
		max_y = maxf(max_y, aabb.position.y + aabb.size.y)
		max_abs_x = maxf(max_abs_x, absf(p.com_world.x))
	var eval := CE.evaluate(root_gene)
	return {
		"leg_count": legs,
		"foot_count": feet,
		"spine_segments": spine,
		"leg_segments": max_chain,          # >1 => knees
		"biped": 1 if feet <= 2 else 0,
		"mass": float(eval.get("total_mass", 0.0)),
		"radius": float(eval.get("body_radius", 1.0)),
		"height": maxf(max_y - min_y, 0.01),
		"width": maxf(max_abs_x * 2.0, 0.01),
	}


# Weighted distance. Structural mismatches (biped vs not, knees vs not) dominate;
# leg count is significant; size differences are minor and normalized.
static func distance(a: Dictionary, b: Dictionary) -> float:
	var d := 0.0
	d += 6.0 * absf(float(a.get("biped", 0)) - float(b.get("biped", 0)))
	d += 4.0 * absf(_has_knees(a) - _has_knees(b))
	d += 1.2 * absf(float(a.get("leg_count", 0)) - float(b.get("leg_count", 0)))
	d += 0.8 * absf(float(a.get("spine_segments", 0)) - float(b.get("spine_segments", 0)))
	d += 1.0 * _rel(float(a.get("mass", 0.0)), float(b.get("mass", 0.0)))
	d += 0.6 * _rel(float(a.get("height", 0.0)), float(b.get("height", 0.0)))
	d += 0.6 * _rel(float(a.get("width", 0.0)), float(b.get("width", 0.0)))
	return d


static func _has_knees(f: Dictionary) -> float:
	return 1.0 if int(f.get("leg_segments", 1)) > 1 else 0.0


static func _rel(x: float, y: float) -> float:
	var denom := maxf(absf(x) + absf(y), 0.000001)
	return absf(x - y) / denom   # 0 (identical) .. 1 (wildly different)


static func _chain_depth(parts: Array, index: int) -> int:
	# how many locomotor segments are stacked below this one (knee/ankle chain)
	var depth := 1
	var changed := true
	var frontier := [index]
	var seen := {index: true}
	while changed:
		changed = false
		var next: Array = []
		for u in frontier:
			for c in parts:
				if int(c.parent) == int(u) and c.tags.has(&"locomotor") and not seen.has(int(c.index)):
					seen[int(c.index)] = true
					next.append(int(c.index))
					changed = true
		if not next.is_empty():
			depth += 1
			frontier = next
	return depth
