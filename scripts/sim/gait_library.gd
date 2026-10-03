class_name GaitLibrary
extends RefCounted

## Named gait templates (trot, pace, bound, pronk, gallop, walk). Each returns a
## {socket_id -> phase} map for a creature's driven legs, classified by body
## position (left/right + front->back). These are SEEDS the optimizer starts
## from, so "try gallop timing on a quadruped" is a concrete, cheap experiment.

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")

const PATTERNS: Array[StringName] = [&"trot", &"pace", &"bound", &"pronk", &"gallop", &"walk"]


# {socket_id: phase 0..1} for the named pattern. Falls back to a golden spread
# for unknown patterns so the caller always gets a usable seed.
static func phases_for(root_gene: PartGene, pattern: StringName) -> Dictionary:
	var legs := _driven_legs(root_gene)
	if legs.is_empty():
		return {}
	var min_z := INF
	var max_z := -INF
	var x_sum := 0.0
	for leg in legs:
		min_z = minf(min_z, float(leg["z"]))
		max_z = maxf(max_z, float(leg["z"]))
		x_sum += float(leg["x"])
	var x_mid := x_sum / legs.size()
	var z_span := maxf(max_z - min_z, 0.000001)

	var out := {}
	var i := 0
	for leg in legs:
		var side := 1.0 if float(leg["x"]) >= x_mid else 0.0      # right=1, left=0
		var frontness := (float(leg["z"]) - min_z) / z_span        # 0 = front (-z head), 1 = back
		out[leg["id"]] = _phase(pattern, side, frontness, i)
		i += 1
	return out


static func _phase(pattern: StringName, side: float, frontness: float, index: int) -> float:
	match pattern:
		&"trot":   # diagonal pairs together
			return 0.0 if (side > 0.5) == (frontness < 0.5) else 0.5
		&"pace":   # lateral pairs together (same side in phase)
			return side * 0.5
		&"bound":  # front pair vs back pair
			return 0.0 if frontness < 0.5 else 0.5
		&"pronk":  # all legs together
			return 0.0
		&"gallop": # rotary sequence
			return wrapf(frontness * 0.5 + side * 0.1, 0.0, 1.0)
		&"walk":   # 4-beat
			return wrapf(frontness * 0.5 + side * 0.25, 0.0, 1.0)
	return fmod(index * 0.61803, 1.0)   # golden fallback


# Driven legs with body-relative position: locomotor parts with a real hinge.
static func _driven_legs(root_gene: PartGene) -> Array:
	var out: Array = []
	if root_gene == null:
		return out
	var fold := CE.fold_graph(root_gene, Transform3D.IDENTITY)
	for p in fold["parts"]:
		if p.tags.has(&"locomotor") and p.socket != null and p.hinge_axis.length() > CE.EPS:
			var pos: Vector3 = p.com_world
			out.append({"id": p.socket.id, "x": pos.x, "z": pos.z})
	return out
