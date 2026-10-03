class_name ViewportDropTarget
extends Control

## Thin drop adapter. The important legality decision is pure/testable:
## nearest_attach_point + SocketCatalog.can_attach.


static func nearest_attach_point(root_gene: PartGene, parent_index: int,
		world_point: Vector3) -> Dictionary:
	if root_gene == null:
		return {"ok": false, "reason": "missing root"}
	var fold := CharacteristicsEvaluator.fold_graph(root_gene, Transform3D.IDENTITY)
	var parts: Array = fold["parts"]
	if parent_index < 0 or parent_index >= parts.size():
		return {"ok": false, "reason": "missing parent"}
	var part = parts[parent_index]
	var parent_gene := _gene_by_index(root_gene, parent_index)
	if parent_gene == null:
		return {"ok": false, "reason": "missing parent gene"}
	var best: AttachPoint = null
	var best_d := INF
	for point in SocketCatalog.points_for(parent_gene.definition):
		var wp: Vector3 = part.xform * point.local_pose.origin
		var d := wp.distance_squared_to(world_point)
		if d < best_d:
			best_d = d
			best = point
	if best == null:
		return {"ok": false, "reason": "no attach points"}
	return {"ok": true, "point": best, "distance_sq": best_d}


static func can_drop_part(root_gene: PartGene, parent_index: int, part_id: StringName,
		world_point: Vector3) -> Dictionary:
	var child := PartCatalog.clone_template(part_id)
	if child == null:
		return {"ok": false, "reason": "unknown part"}
	var nearest := nearest_attach_point(root_gene, parent_index, world_point)
	if not bool(nearest["ok"]):
		return nearest
	var parent_gene := _gene_by_index(root_gene, parent_index)
	var child_tags: Array[StringName] = []
	child_tags.assign(child.tags)
	var gate := SocketCatalog.can_attach(parent_gene, (nearest["point"] as AttachPoint).id, child_tags)
	if not bool(gate["ok"]):
		return gate
	return {"ok": true, "point": nearest["point"], "part_id": part_id}


static func _gene_by_index(root_gene: PartGene, index: int) -> PartGene:
	var counter := [0]
	return _walk_gene(root_gene, index, counter)


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
