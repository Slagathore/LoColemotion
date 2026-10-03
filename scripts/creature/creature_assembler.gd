class_name CreatureAssembler
extends RefCounted

## Builds a display-only Node3D of MeshInstance3D parts from a genome.
##
## Key design choice: it consumes CharacteristicsEvaluator.fold_graph output — the
## exact world `xform` and `dims` the evaluator scores — instead of re-walking the
## gene tree. That makes visual/stat divergence impossible and inherits the
## evaluator's cycle/null guards for free.
##
## Flat (not articulated) is intentional for Tier 1: you can't animate yet, and the
## hinge hierarchy is a Tier-3 concern. Size lives in the mesh (from `dims`); the
## node transform is the rigid (scaleless) `xform` — never set node scale, or it
## double-applies and diverges from the frame law.

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")


static func build(root: PartGene, root_xform: Transform3D = Transform3D.IDENTITY,
		mat = null) -> Node3D:
	var container := Node3D.new()
	container.name = "AssembledCreature"
	var fold := CE.fold_graph(root, root_xform)
	var i := 0
	for p in fold["parts"]:
		var mi := MeshInstance3D.new()
		mi.name = "part_%d_%s" % [i, p.definition.part_type]
		mi.set_meta("part_index", i)
		mi.mesh = PartMeshProvider.mesh_for_part(_gene_by_index(root, i), p.dims)
		mi.transform = p.xform                 # rigid world transform; scale is baked into the mesh
		if mat is Callable:
			mi.material_override = mat.call(p, i)
		elif mat != null:
			mi.material_override = mat
		container.add_child(mi)
		i += 1
	return container


static func _gene_by_index(root: PartGene, index: int) -> PartGene:
	var counter := [0]
	return _walk_gene(root, index, counter)


static func _walk_gene(g: PartGene, index: int, counter: Array) -> PartGene:
	if g == null:
		return null
	if int(counter[0]) == index:
		return g
	counter[0] = int(counter[0]) + 1
	for child in g.children:
		var found := _walk_gene(child, index, counter)
		if found != null:
			return found
	return null
